module Nanite
  class Log
    def initialize(options, identity)
      @file = File.join((options[:log_dir] || options[:root] || Dir.pwd), "nanite.#{identity}.log")
      @logger = Logger.new(file)
      @logger.level = log_level(options[:log_level])
    end

    def file
      @file
    end

    def method_missing(method, *args)
      @logger.send(method, *args)
    end

    private

    def log_level(level)
      case level
      when 'fatal'
        Logger::FATAL
      when 'error'
        Logger::ERROR
      when 'warn'
        Logger::WARN
      when 'info'
        Logger::INFO
      when 'debug'
        Logger::DEBUG
      else
        Logger::INFO
      end
    end
  end
end