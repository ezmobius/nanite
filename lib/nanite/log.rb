require 'nanite/config'
require 'nanite/log/formatter'
require 'logger'

module Nanite
  class Log
  
    @logger = nil
    
    class << self
      attr_accessor :logger, :log_level, :log_file #:nodoc
      
      # Use Nanite::Logger.init when you want to set up the logger manually.  Arguments to this method
      # get passed directly to Logger.new, so check out the documentation for the standard Logger class
      # to understand what to do here.
      #
      # If this method is called with no arguments, it will log to STDOUT at the :info level.
      #
      # It also configures the Logger instance it creates to use the custom Nanite::Log::Formatter class.
      def init(identity, path = false)
        @file = STDOUT
        if path
          @log_file = File.join(path, "nanite.#{identity}.log")
        end
        @logger = Logger.new(log_file)
        @logger.formatter = Nanite::Log::Formatter.new
        level(@log_level = :info)
      end
      
      # Sets the level for the Logger object by symbol.  Valid arguments are:
      #
      #  :debug
      #  :info
      #  :warn
      #  :error
      #  :fatal
      #
      # Throws an ArgumentError if you feed it a bogus log level.
      def level(loglevel)
        init() unless @logger
        case loglevel
        when :debug
          @logger.level = Logger::DEBUG
        when :info
          @logger.level = Logger::INFO
        when :warn
          @logger.level = Logger::WARN
        when :error
          @logger.level = Logger::ERROR
        when :fatal
          @logger.level = Logger::FATAL
        else
          raise ArgumentError, "Log level must be one of :debug, :info, :warn, :error, or :fatal"
        end
      end
      
      # Passes any other method calls on directly to the underlying Logger object created with init. If
      # this method gets hit before a call to Nanite::Logger.init has been made, it will call 
      # Nanite::Logger.init() with no arguments.
      def method_missing(method_symbol, *args)
        init(identity) unless @logger
        if args.length > 0
          @logger.send(method_symbol, *args)
        else
          @logger.send(method_symbol)
        end
      end
      
    end # class << self
  end
end