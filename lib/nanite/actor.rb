require 'nanite/resource'
module Nanite
  class Actor
    class << self      
      def provides(*resources)
        @provides ||= []
        resources.each do |res|
          @provides << Nanite::Resource.new(res)
        end
        @provides 
      end  
    end
      
    def provides
      self.class.provides
    end
  
    def to_s
      "<Actor[#{self.class.name}]: provides=#{provides.map{|n| n.to_s }.join(', ')}>"
    end
  
    def spawn(arg, *argv, &block)
      # setup output hash
      output = {:stdout => '', :stderr => ''}
      default_options = {'stdout' => output[:stdout], 'stderr' => output[:stderr]}
      
      # add default options to fill output hash
      if argv.size > 1 and Hash === argv.last
        argv.last.merge!(default_options)  
      else
        argv.push default_options
      end
      
      
      # catch any spawn errors and return 
      begin
        status = Open4::spawn(arg, *argv)
      rescue Open4::SpawnError => e
        raise ActorInternalError, e.message
      end
      
      if block_given?
        formatted_output = yield(output[:stdout])
        output[:stdout] = formatted_output
      end
      
      output.merge({:status => status})
    end
  end
end  