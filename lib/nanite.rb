require 'rubygems'
require 'amqp'
require 'mq'
$:.unshift File.dirname(__FILE__)
require 'nanite/resource'
require 'nanite/packets'
require 'nanite/reducer'
require 'nanite/dispatcher'
require 'nanite/actor'


module Nanite
  
  VERSION = '0.1' unless defined?(Nanite::VERSION)
  
  class << self
    attr_accessor :identity, :user, :pass, :root, :vhost, :file_root, :files, :host
    
    attr_accessor :default_resources, :last_ping, :ping_time, :return_address
        
    def op(type, payload, *resources, &blk)
      token = Nanite.gen_token
      op = Nanite::Op.new(type, payload, *resources)
      op.reply_to = Nanite.return_address
      Nanite.mapper.route(op) do |answer|
        Nanite.callbacks[token] = blk if blk
        Nanite.reducer.watch_for(answer)
        Nanite.pending[token] = answer.token
      end
      token
    end
    
    def get_file(filename, *resources, &blk)
      token = Nanite.gen_token
      file = Nanite::GetFile.new(filename, *resources)
      file.reply_to = Nanite.return_address
      Nanite.mapper.file(file) do |f|
        Nanite.callbacks[token] = blk if blk
        Nanite.reducer.watch_for(f)
        Nanite.pending[token] = f.token
      end
      token
    end
      
    def broadcast_file(filename, dest, domain='global')
      begin
        file_push = FileStart.new(filename, dest)
        Nanite.amq.topic('file broadcast').publish(Marshal.dump(file_push), :key => "nanite.filepeer.#{domain}")
        file = File.open(file_push.filename, 'rb')
        res = Nanite::FileChunk.new(file_push.token)
        while chunk = file.read(65536)
          res.chunk = chunk
          Nanite.amq.topic('file broadcast').publish(Marshal.dump(res), :key => "nanite.filepeer.#{domain}")
        end
        fend = FileEnd.new(file_push.token)
        Nanite.amq.topic('file broadcast').publish(Marshal.dump(fend), :key => "nanite.filepeer.#{domain}")
      ensure
        file.close
      end
    end
    
    class FileState
      
      def initialize(token, dest)
        @token = token
        @dest = File.open(File.join(Nanite.file_root,dest), 'wb')
      end
      
      def handle_packet(packet)
        case packet
        when FileChunk
          @dest.write(packet.chunk)
        when FileEnd
          puts "file written: #{@dest}"
          @dest.close
          Nanite.files.delete(packet.token)
        end  
      end
      
    end  
    
    def subscribe_to_files(domain='global')
      puts "subscribing to file broadcasts for #{domain}"
      @files ||= {}
      Nanite.amq.queue("files#{Nanite.return_address}").bind(Nanite.amq.topic('file broadcast'), :key => "nanite.filepeer.#{domain}").subscribe{ |packet|
        case msg = Marshal.load(packet)
        when FileStart
          @files[msg.token] = FileState.new(msg.token, msg.dest)
        when FileChunk, FileEnd
          if file = @files[msg.token]
            file.handle_packet(msg)
          end            
        end
      }
    end
    
    def transfer(file, local, *resources)
      fd = File.open(local, 'wb')
      get_file(file, *resources) do |c|
        if c
          fd.write(c)
        else
          fd.close
        end    
      end 
    end
    
    def send_ping
      ping = Nanite::Ping.new(Nanite.user, Nanite.identity)
      Nanite.amq.topic('heartbeat').publish(Marshal.dump(ping), :key => 'nanite.pings')
    end
    
    def advertise_resources
      puts "advertise_resources"
      reg = Nanite::Register.new(Nanite.user, Nanite.identity, Nanite::Dispatcher.all_resources)
      Nanite.amq.topic('registration').publish(Marshal.dump(reg), :key => 'nanite.register')
    end
    
    def start_console
      puts "starting console"
      require 'readline'
      Thread.new{
        while l = Readline.readline('>> ')
          unless l.nil? or l.strip.empty?
            Readline::HISTORY.push(l)
            eval l
          end
        end
      }
    end
    
    def load_actors
      Dir["#{Nanite.root}/actors/*.rb"].each do |actor|
        puts "loading actor: #{actor}"
        require actor
      end  
    end
    
    def start(opts={})
      config = YAML::load(IO.read(File.expand_path(File.join(opts[:root], 'config.yml')))) rescue {}
      opts = config.merge(opts)
      Nanite.root              = opts[:root]
      Nanite.identity          = opts[:identity] || Nanite.gen_token
      Nanite.user              = opts[:user]
      Nanite.pass              = opts[:pass]
      Nanite.host              = opts[:host] || '0.0.0.0'
      Nanite.vhost             = opts[:vhost]
      Nanite.return_address    = opts[:return_address] || Nanite.gen_token
      Nanite.file_root         = opts[:file_root] || Dir.pwd
      Nanite.default_resources = opts[:resources].map {|r| Nanite::Resource.new(r)}

      AMQP.start :user  => Nanite.user,
                 :pass  => Nanite.pass,
                 :vhost => Nanite.vhost,
                 :host  => Nanite.host
      
      load_actors
      advertise_resources
                              
      EM.add_periodic_timer(30) do
        send_ping
      end
      
      Nanite.amq.queue(Nanite.identity, :exclusive => true).subscribe{ |msg|
        Nanite::Dispatcher.handle(Marshal.load(msg))
      }
      
      Nanite.amq.queue(Nanite.return_address, :exclusive => true).subscribe{ |msg|
        msg = Marshal.load(msg)
        Nanite.reducer.handle_result(msg)
      }
      
      start_console if opts[:console]
    end  
    
    def reducer
      @reducer ||= Nanite::Reducer.new
    end
    
    def mapper
      Thread.current[:mapper] ||= MQ.new.rpc('mapper')
    end  
    
    def amq
      Thread.current[:mq] ||= MQ.new
    end
    
    def pending
      @pending ||= {}
    end
    
    def callbacks
      @callbacks ||= {}
    end
    
    def results
      @results ||= {}
    end
    
    def gen_token
      values = [
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x1000000),
        rand(0x1000000),
      ]
      "%04x%04x%04x%04x%04x%06x%06x" % values
    end
  end  
end  