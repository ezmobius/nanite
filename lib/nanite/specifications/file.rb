module Nanite
  module Specification
    class File < Base
      attr_accessor :path, :owner, :perms
      
      def initialize(path = nil)
        self.path = path
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
    end
  end
end