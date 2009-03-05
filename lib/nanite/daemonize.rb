module Nanite
  module DaemonizeHelper
    def daemonize
      exit if fork
      Process.setsid
      exit if fork
      #$stdin.reopen("/dev/null")
      #$stdout.reopen(log.file, "a")
      #$stderr.reopen($stdout)
    end
  end
end