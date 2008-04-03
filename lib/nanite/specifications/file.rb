module Nanite
  module Specification
    class File < Base
      attr_accessor :path, :owner, :perms
      
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
        
        if perms && stat.mode[2,4].oct != perms.oct
          file.chmod perms.oct
        end
      end
    end
  end
end