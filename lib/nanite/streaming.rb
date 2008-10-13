module FileStreaming  
  def broadcast_file(filename, dest, domain='global')
    begin
      file_push = FileStart.new(filename, dest)
      Nanite.amq.topic('file broadcast').publish(Nanite.dump_packet(file_push), :key => "nanite.filepeer.#{domain}")
      file = File.open(file_push.filename, 'rb')
      res = Nanite::FileChunk.new(file_push.token)
      while chunk = file.read(65536)
        res.chunk = chunk
        Nanite.amq.topic('file broadcast').publish(Nanite.dump_packet(res), :key => "nanite.filepeer.#{domain}")
      end
      fend = FileEnd.new(file_push.token)
      Nanite.amq.topic('file broadcast').publish(Nanite.dump_packet(fend), :key => "nanite.filepeer.#{domain}")
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
    Nanite.amq.queue("files#{Nanite.identity}").bind(Nanite.amq.topic('file broadcast'), :key => "nanite.filepeer.#{domain}").subscribe{ |packet|
      case msg = Nanite.load_packet(packet)
      when FileStart
        @files[msg.token] = FileState.new(msg.token, msg.dest)
      when FileChunk, FileEnd
        if file = @files[msg.token]
          file.handle_packet(msg)
        end            
      end
    }
  end

end