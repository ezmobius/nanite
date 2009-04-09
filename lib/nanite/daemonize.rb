module Nanite
  module DaemonizeHelper
    def daemonize
      exit if fork
      Process.setsid
      exit if fork
      File.umask 0000
      STDIN.reopen "/dev/null"
      STDOUT.reopen "/dev/null", "a"
      STDERR.reopen STDOUT
    end
  end
end