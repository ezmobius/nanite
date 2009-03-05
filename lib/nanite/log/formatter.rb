require 'logger'
require 'time'

module Nanite
  class Log
    class Formatter < Logger::Formatter
      @@show_time = true
      
      def self.show_time=(show=false)
        @@show_time = show
      end
      
      # Prints a log message as '[time] severity: message' if Nanite::Log::Formatter.show_time == true.
      # Otherwise, doesn't print the time.
      def call(severity, time, progname, msg)
        if @@show_time
          sprintf("[%s] %s: %s\n", time.rfc2822(), severity, msg2str(msg))
        else
          sprintf("%s: %s\n", severity, msg2str(msg))
        end
      end
      
      # Converts some argument to a Logger.severity() call to a string.  Regular strings pass through like
      # normal, Exceptions get formatted as "message (class)\nbacktrace", and other random stuff gets 
      # put through "object.inspect"
      def msg2str(msg)
        case msg
        when ::String
          msg
        when ::Exception
          "#{ msg.message } (#{ msg.class })\n" <<
            (msg.backtrace || []).join("\n")
        else
          msg.inspect
        end
      end
    end
  end
end