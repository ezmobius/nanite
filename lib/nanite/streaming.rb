module FileStreaming
  def broadcast_file(filename, options = {})

    domain   = options[:domain] || 'global'
    filepath = File.expand_path(options[:filename] || filename)
    filename = File.basename(filename)
    dest     = options[:destination] || filename

    if File.exist?(filename)
      file = File.open(filename, 'rb')
      begin
        file_push = Nanite::FileStart.new(filename, dest)
        Nanite.amq.topic('file broadcast').publish(Nanite.dump_packet(file_push), :key => "nanite.filepeer.#{domain}")
        res = Nanite::FileChunk.new(file_push.token)
        while chunk = file.read(65536)
          res.chunk = chunk
          Nanite.amq.topic('file broadcast').publish(Nanite.dump_packet(res), :key => "nanite.filepeer.#{domain}")
        end
        fend = Nanite::FileEnd.new(file_push.token, options[:meta])
        Nanite.amq.topic('file broadcast').publish(Nanite.dump_packet(fend), :key => "nanite.filepeer.#{domain}")
      ensure
        file.close
        true
      end
    else
      return nil
    end
  end

  class FileState

    def initialize(token, dest, domain)
      @token = token
      @domain = domain
      @filename = File.join(Nanite.file_root,dest)
      @dest = File.open(@filename, 'wb')
    end

    def handle_packet(packet)
      case packet
      when Nanite::FileChunk
        @dest.write(packet.chunk)
      when Nanite::FileEnd
        puts "file written: #{@dest}"
        @dest.close
        Nanite.callbacks[@domain].call(@filename, packet.meta) if Nanite.callbacks[@domain]
        Nanite.files.delete(packet.token)
      end
    end

  end

  def subscribe_to_files(domain='global', &blk)
    puts "subscribing to file broadcasts for #{domain}"
    @files ||= {}
    Nanite.callbacks[domain] = blk if blk
    Nanite.amq.queue("files#{Nanite.identity}").bind(Nanite.amq.topic('file broadcast'), :key => "nanite.filepeer.#{domain}").subscribe{ |packet|
      case msg = Nanite.load_packet(packet)
      when Nanite::FileStart
        @files[msg.token] = FileState.new(msg.token, msg.dest, domain)
      when Nanite::FileChunk, Nanite::FileEnd
        if file = @files[msg.token]
          file.handle_packet(msg)
        end
      end
    }
  end

end
