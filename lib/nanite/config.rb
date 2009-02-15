module Nanite

  COMMON_DEFAULT_OPTIONS = {:pass => 'testing', :vhost => '/nanite', :secure => false, :host => '0.0.0.0',
    :log_level => :info, :format => :marshal, :daemonize => false, :console => false, :root => Dir.pwd}

  module CommonConfig
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

      opts.on("-f", "--format FORMAT", "The serialization type to use for transfering data. Can be marshal, json or yaml. Default is marshal") do |json|
        options[:format] = :json
      end

      opts.on("-d", "--daemonize", "Run #{type} as a daemon") do |d|
        options[:daemonize] = true
      end

      opts.on("-l", "--log-level LEVEL", "Specify the log level (fatal, error, warn, info, debug). Default is info") do |level|
        options[:log_level] = level
      end

      opts.on("--version", "Show the nanite version number") do |res|
        puts "Nanite Version #{opts.version}"
        exit
      end
    end
  end
end