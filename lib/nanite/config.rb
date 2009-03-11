module Nanite

  COMMON_DEFAULT_OPTIONS = {:pass => 'testing', :vhost => '/nanite', :secure => false, :host => '0.0.0.0',
    :log_level => :info, :format => :marshal, :daemonize => false, :console => false, :root => Dir.pwd}

  module CommonConfig
    def setup_mapper_options(opts, options)
      setup_common_options(opts, options, 'mapper')

      opts.on("-a", "--agent-timeout", "How long to wait before an agent is considered to be offline and thus removed from the list of available agents.") do |timeout|
        options[:agent_timeout] = timeout
      end

      opts.on("-r", "--offline-redelivery-frequency", "The frequency in seconds that messages stored in the offline queue will be retrieved for attempted redelivery to the nanites. Default is 10 seconds.") do |frequency|
        options[:offline_redelivery_frequency] = frequency
      end

      opts.on("--persistent", "Instructs the AMQP broker to save messages to persistent storage so that they aren't lost when the broker is restarted. Can be overriden on a per-message basis using the request and push methods.") do
        options[:persistent] = true
      end

      opts.on("--offline-failsafe", "Store messages in an offline queue when all the nanites are offline. Messages will be redelivered when nanites come online. Can be overriden on a per-message basis using the request methods.") do
        options[:offline_failsafe] = true
      end
    end
    
    def setup_common_options(opts, options, type)
      opts.version = Nanite::VERSION

      opts.on("-i", "--irb-console", "Start #{type} in irb console mode.") do |console|
        options[:console] = 'irb'
      end

      opts.on("-u", "--user USER", "Specify the rabbitmq username.") do |user|
        options[:user] = user
      end

      opts.on("-h", "--host HOST", "Specify the rabbitmq hostname.") do |host|
        options[:host] = host
      end

      opts.on("-P", "--port PORT", "Specify the rabbitmq PORT, default 5672.") do |port|
        options[:port] = port
      end

      opts.on("-p", "--pass PASSWORD", "Specify the rabbitmq password") do |pass|
        options[:pass] = pass
      end

      opts.on("-t", "--token IDENITY", "Specify the #{type} identity.") do |ident|
        options[:identity] = ident
      end

      opts.on("-v", "--vhost VHOST", "Specify the rabbitmq vhost") do |vhost|
        options[:vhost] = vhost
      end

      opts.on("-s", "--secure", "Use Security features of rabbitmq to restrict nanites to themselves") do
        options[:secure] = true
      end

      opts.on("-f", "--format FORMAT", "The serialization type to use for transfering data. Can be marshal, json or yaml. Default is marshal") do |fmt|
        options[:format] = fmt
      end

      opts.on("-d", "--daemonize", "Run #{type} as a daemon") do |d|
        options[:daemonize] = true
      end
      
      opts.on("--pid-dir PATH", "Specify the pid path, only used with daemonize") do |dir|
        options[:pid_dir] = dir
      end

      opts.on("-l", "--log-level LEVEL", "Specify the log level (fatal, error, warn, info, debug). Default is info") do |level|
        options[:log_level] = level
      end
      
      opts.on("--log-dir PATH", "Specify the log path") do |dir|
        options[:log_dir] = dir
      end

      opts.on("--version", "Show the nanite version number") do |res|
        puts "Nanite Version #{opts.version}"
        exit
      end
    end
  end
end