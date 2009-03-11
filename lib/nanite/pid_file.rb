module Nanite
  class PidFile
    def initialize(identity, options)
      @pid_dir = File.expand_path(options[:pid_dir] || options[:root] || Dir.pwd)
      @pid_file = File.join(@pid_dir, "nanite.#{identity}.pid")
    end
    
    def check
      if pid = read_pid
        if process_running? pid
          raise "#{@pid_file} already exists (pid: #{pid})"
        else
          Log.info "removing stale pid file: #{@pid_file}"
          remove
        end
      end
    end
    
    def ensure_dir
      FileUtils.mkdir_p @pid_dir
    end
    
    def write
      ensure_dir
      open(@pid_file,'w') {|f| f.write(Process.pid) }
      File.chmod(0644, @pid_file)
    end
    
    def remove
      File.delete(@pid_file) if exists?
    end
    
    def read_pid
      open(@pid_file,'r') {|f| f.read.to_i } if exists?
    end
    
    def exists?
      File.exists? @pid_file
    end

    def to_s
      @pid_file
    end
    
    private
      def process_running?(pid)
        Process.getpgid(pid) != -1
      rescue Errno::ESRCH
        false
      end
  end
end