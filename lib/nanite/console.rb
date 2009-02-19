module Nanite
  module ConsoleHelper
    def self.included(base)
      @@base = base
    end
    
    def start_console
      puts "Starting #{@@base.name.split(":").last.downcase} console (#{self.identity}) (Nanite #{Nanite::VERSION})"
      Thread.new do
        Console.start(self)
      end
    end
  end
  
  module Console
    class << self; attr_accessor :instance; end

    def self.start(binding)
      require 'irb'
      old_args = ARGV.dup
      ARGV.replace ["--simple-prompt"]

      IRB.setup(nil)
      self.instance = IRB::Irb.new(IRB::WorkSpace.new(binding))

      @CONF = IRB.instance_variable_get(:@CONF)
      @CONF[:IRB_RC].call self.instance.context if @CONF[:IRB_RC]
      @CONF[:MAIN_CONTEXT] = self.instance.context

      catch(:IRB_EXIT) { self.instance.eval_input }
    ensure
      ARGV.replace old_args
      # Clean up tty settings in some evil, evil cases
      begin; catch(:IRB_EXIT) { irb_exit }; rescue Exception; end
      # Make nanite exit when irb does
      EM.stop if EM.reactor_running?
    end
  end
end
