module Nanite
  module DaemonizeHelper
    def daemonize(identity, options = {})
      exit if fork
      Process.setsid
      exit if fork
      STDIN.reopen "/dev/null"
      STDOUT.reopen "#{options[:log_path]}/nanite.#{identity}.out", "a"
      STDERR.reopen "#{options[:log_path]}/nanite.#{identity}.err", "a"
      File.umask 0000
    end
  end
end