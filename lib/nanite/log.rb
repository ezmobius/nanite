require 'nanite/config'
require 'nanite/log/formatter'
require 'logger'

module Nanite
  class Log
  
    @logger = nil

    # Map log levels symbols to values
    LEVELS = { :debug => Logger::DEBUG,
               :info  => Logger::INFO,
               :warn  => Logger::WARN,
               :error => Logger::ERROR,
               :fatal => Logger::FATAL }
    
    class << self
      attr_accessor :logger, :level, :file #:nodoc
      
      # Use Nanite::Logger.init when you want to set up the logger manually.
      # If this method is called with no arguments, it will log to STDOUT at the :info level.
      # It also configures the Logger instance it creates to use the custom Nanite::Log::Formatter class.
      def init(identity = nil, path = false)
        if path
          @file = File.join(path, "nanite.#{identity}.log")
        else
          @file = STDOUT
        end
        @logger = Logger.new(file)
        @logger.formatter = Nanite::Log::Formatter.new
        Log.level = :info
      end
      
      # Sets the level for the Logger by symbol or by command line argument.
      # Throws an ArgumentError if you feed it a bogus log level (that is not
      # one of :debug, :info, :warn, :error, :fatal or the corresponding strings or a valid Logger level)
      def level=(loglevel)
        init unless @logger
        lvl = case loglevel
          when String  then loglevel.intern
          when Integer then LEVELS.invert[loglevel]
          else loglevel
        end
        unless LEVELS.include?(lvl)
          raise(ArgumentError, 'Log level must be one of :debug, :info, :warn, :error, or :fatal')
        end
        @logger.info("[setup] setting log level to #{lvl.to_s.upcase}")
        @level = lvl
        @logger.level = LEVELS[lvl]
      end

      # Passes any other method calls on directly to the underlying Logger object created with init. If
      # this method gets hit before a call to Nanite::Logger.init has been made, it will call 
      # Nanite::Logger.init() with no arguments.
      def method_missing(method_symbol, *args)
        init unless @logger
        if args.length > 0
          @logger.send(method_symbol, *args)
        else
          @logger.send(method_symbol)
        end
      end
      
    end # class << self
  end
end
