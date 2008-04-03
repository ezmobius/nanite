require 'etc'

module Nanite
  module Specification
    class File < Base
      attr_accessor :path, :owner, :group, :perms
      
      def initialize(path = nil)
        self.path = path
      end
      
      def perms=(value)
        raise ArgumentError unless value.kind_of?(String)
        @perms = value
      end
      
      def content(value, *args)
        if value.kind_of?(String) or value.kind_of?(Symbol) or value.respond_to?(:read)
          @content = value
        else
          raise ArgumentError
        end
      end
      
      def read_content
        case @content
          when String
            @content
          else
            @content.read if @content.respond_to?(:read)
        end
      end
      
      def update_system
        file = ::File.new(path)
        stat = file.stat
        
        set_file_perms(file, stat)
        set_file_ownership(file, stat)
        set_file_content(file)
      end
      
      private
        def set_file_perms(file,stat)
          if perms && stat.mode[2,4].oct != perms.oct
            file.chmod perms.oct
          end
        end
        
        # TODO These should maybe be combined, and should protect against invalid user/group names
        def set_file_ownership(file, stat)
          if owner and owner != Etc.getpwuid(stat.uid).name
            file.chown(Etc.getpwnam(owner).uid, stat.gid)
          end

          if group and group != Etc.getgrgid(stat.gid).name
            file.chown(stat.uid, Etc.getgrnam(group).gid)
          end
        end
        
        def set_file_content(file)
          if read_content != file.read
            file.write(read_content)
          end
        end
    end
  end
end