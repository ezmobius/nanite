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
    def broadcast_file(filename, options = {})

      domain   = options[:domain] || 'global'
      filepath = File.expand_path(options[:filename] || filename)
      filename = File.basename(filename)
      dest     = options[:destination] || filename

      if File.exist?(filepath)
        file = File.open(filepath, 'rb')
        begin
          file_push = Nanite::FileStart.new(filename, dest)
          Nanite.amq.topic('file broadcast').publish(Nanite.dump_packet(file_push), :key => "nanite.filepeer.#{domain}")
          res = Nanite::FileChunk.new(file_push.token)
          while chunk = file.read(16384)
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

    # FileState represents a file download in progress.
    # It incapsulates the following information:
    #
    # * unique operation token
    # * domain (namespace for file streaming operations)
    # * file IO chunks are written to on receiver's side
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
          Nanite.log.debug "written chunk to #{@dest.inspect}"
          @dest.write(packet.chunk)
        when Nanite::FileEnd
          Nanite.log.debug "#{@dest.inspect} receiving is completed"
          @dest.close
          if cback = Nanite.callbacks[@domain]
            cback.call(@filename, packet.meta)
          end
          Nanite.files.delete(packet.token)
        end
      end

    end

    def subscribe_to_files(domain='global', &blk)
      log.info "subscribing to file broadcasts for #{domain}"
      @files ||= {}
      callbacks[domain] = blk if blk
      amq.queue("files#{identity}").bind(amq.topic('file broadcast'), :key => "nanite.filepeer.#{domain}").subscribe do |packet|
        case msg = load_packet(packet)
        when FileStart
          @files[msg.token] = FileState.new(msg.token, msg.dest, domain)
        when FileChunk, FileEnd
          if file = @files[msg.token]
            file.handle_packet(msg)
          end
        end
      end
    end

  end
end
