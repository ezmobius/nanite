module Nanite
  # Nanite actors can transfer files to each other.
  #
  # ==== Options
  #
  # filename    : you guessed it, name of the file!
  # domain      : part of the routing key used to locate receiver(s)
  # destination : is a name of the file as it gonna be stored at the destination
  # meta        : 
  #
  # File streaming is done in chunks. When file streaming starts,
  # Nanite::FileStart packet is sent, followed by one or more (usually more ;))
  # Nanite::FileChunk packets each 16384 (16K) in size. Once file streaming is done,
  # Nanite::FileEnd packet is sent.
  #
  # 16K is a packet size because on certain UNIX-like operating systems, you cannot read/write
  # more than that in one operation via socket.
  #
  # ==== Domains
  #
  # Streaming happens using a topic exchange called 'file broadcast', with keys
  # formatted as "nanite.filepeer.DOMAIN". Domain variable in the key lets senders and
  # receivers find each other in the cluster. Default domain is 'global'.
  #
  # Domains also serve as a way to register a callback Nanite agent executes once file
  # streaming is completed. If a callback with name of domain is registered, it is called.
  #
  # Callbacks are registered by passing a block to subscribe_to_files method.
  module FileStreaming
    def broadcast_file(filename, file, options = {})

      domain   = options[:domain] || 'global'
      filename = File.basename(filename)
      dest     = options[:destination] || filename

        begin
          file_push = Nanite::FileStart.new(filename, dest)
          amq.topic('file broadcast').publish(dump_packet(file_push), :key => "nanite.filepeer.#{domain}")
          res = Nanite::FileChunk.new(file_push.token)
          while chunk = file.read(16384)
            res.chunk = chunk
            amq.topic('file broadcast').publish(dump_packet(res), :key => "nanite.filepeer.#{domain}")
          end
          fend = Nanite::FileEnd.new(file_push.token, options[:meta])
          amq.topic('file broadcast').publish(dump_packet(fend), :key => "nanite.filepeer.#{domain}")
          ""
        ensure
          file.close
          true
        end
    end

    # FileState represents a file download in progress.
    # It incapsulates the following information:
    #
    # * unique operation token
    # * domain (namespace for file streaming operations)
    # * file IO chunks are written to on receiver's side
    class FileState

      def initialize(token, dest, domain, write, blk)
        @token = token
        @cb = blk
        @domain = domain
        @write = write
        
        if write
          @filename = File.join(Nanite.agent.file_root, dest)
          @dest = File.open(@filename, 'wb')
        else
          @dest = dest
        end

        @data = ""
      end

      def handle_packet(packet)
        case packet
        when Nanite::FileChunk
          Nanite.log.debug "written chunk to #{@dest.inspect}"
          @data << packet.chunk
        
          if @write
            @dest.write(packet.chunk)
          end
        when Nanite::FileEnd
          Nanite.log.debug "#{@dest.inspect} receiving is completed"
          if @write
            @dest.close
          end

          @cb.call(@data, @dest, packet.meta)
        end
      end

    end

    def subscribe_to_files(domain='global', write=false, &blk)
      log.info "subscribing to file broadcasts for #{domain}"
      @files ||= {}
      amq.queue("files#{domain}").bind(amq.topic('file broadcast'), :key => "nanite.filepeer.#{domain}").subscribe do |packet|
        case msg = load_packet(packet)
        when FileStart
          @files[msg.token] = FileState.new(msg.token, msg.dest, domain, write, blk)
        when FileChunk, FileEnd
          if file = @files[msg.token]
            file.handle_packet(msg)
          end
        end
      end
    end
  end
end
