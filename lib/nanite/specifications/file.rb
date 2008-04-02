module Nanite
  module Specification
    class File
      attr_accessor :path, :owner, :perms, :content
      
      def initialize(path = nil)
        self.path = path
      end
      
      def content=(value)
        case value
          when StringIO, IO, String, Symbol
            @content = value
          else
            raise ArgumentError
        end
      end
    end
  end
end