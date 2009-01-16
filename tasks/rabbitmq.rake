# Inspired by rabbitmq.rake the Redbox project at http://github.com/rick/redbox/tree/master

class RabbitMQ
  
  def self.basedir
    basedir = File.expand_path(File.dirname(__FILE__) + "/../") # ick
  end
  
  def self.rabbitdir
    "#{basedir}/vendor/rabbitmq-server-1.5.0"
  end

  def self.dtach_socket
    "#{basedir}/tmp/rabbitmq.dtach"
  end

  # Just check for existance of dtach socket
  def self.running?
    File.exists? dtach_socket
  end
  
  def self.setup_environment
    ENV['MNESIA_BASE']        ||= "#{basedir}/db/mnesia"
    ENV['LOG_BASE']           ||= "#{basedir}.log"
    ENV['RABBITMQ_NODE_ONLY'] ||= "0" # to get an erlang shell
  end

  def self.start
    setup_environment
    exec "dtach -n #{dtach_socket} #{rabbitdir}/scripts/rabbitmq-server"
  end
  
  def self.attach
    exec "dtach -a #{dtach_socket}"
  end
  
  def self.stop
    system "#{rabbitdir}/scripts/rabbitmqctl stop"
  end

end

namespace :rabbitmq do

  desc "Start RabbitMQ"
  task :start do
    RabbitMQ.start
  end

  desc "stop"
  task :stop do
    RabbitMQ.stop
  end

  desc "Attach to RabbitMQ dtach socket"
  task :attach do
    RabbitMQ.attach
  end

  namespace :package do

    desc "Download package"
    task :download do
      Dir.chdir("vendor") do
        system "wget http://www.rabbitmq.com/releases/rabbitmq-server/v1.5.0/rabbitmq-server-1.5.0.tar.gz"
      end
    end
    
  end


end
  