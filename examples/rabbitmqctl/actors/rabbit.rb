class Rabbit
  include Nanite::Actor
  
  expose :add_user,:delete_user, :change_password, :list_users,
         :add_vhost, :delete_vhost, :list_vhosts,
         :map_user_vhost, :unmap_user_vhost, :list_user_vhosts, :list_vhost_users,
         :list_queues, :list_exchanges, :list_exchanges, :list_connections

  def list_queues(vhost)
    parse_list(rabbitmqctl(:list_queues, vhost.empty? ? "" : "-p #{vhost}")).first
  end
  
  def list_exchanges(vhost)
    parse_list(rabbitmqctl(:list_exchanges, vhost.empty? ? "" : "-p #{vhost}")).first
  end
  
  def list_bindings(vhost)
    parse_list(rabbitmqctl(:list_bindings, vhost.empty? ? "" : "-p #{vhost}")).first
  end

  def list_connections(payload)
    parse_list(rabbitmqctl(:list_connections)).first
  end
    
  def list_users(payload)
    parse_list(rabbitmqctl(:list_users)).first
  end
  
  def list_vhosts(payload)
    parse_list(rabbitmqctl(:list_vhosts)).first
  end
  
  def list_vhost_users(vhost)
    parse_list(rabbitmqctl(:list_vhost_users, vhost)).first
  end
  
  def list_user_vhosts(user)
    parse_list(rabbitmqctl(:list_user_vhosts, user)).first
  end
  
  def map_user_vhost(payload)
    if String === payload
      payload = JSON.parse(payload)
    end
    res = parse_list(rabbitmqctl(:map_user_vhost, payload['user'], payload['vhost']))
    if res[1]
      "problem mapping user to vhost: #{payload['user']}:#{payload['vhost']} #{res[1]}"
    else
      "successfully mapped user to vhost: #{payload['user']}:#{payload['vhost']}"
    end
  end
  
  def unmap_user_vhost(payload)
    if String === payload
      payload = JSON.parse(payload)
    end
    res = parse_list(rabbitmqctl(:unmap_user_vhost, payload['user'], payload['vhost']))
    if res[1]
      "problem unmapping user from vhost: #{payload['user']}:#{payload['vhost']} #{res[1]}"
    else
      "successfully unmapped user from vhost: #{payload['user']}:#{payload['vhost']}"
    end
  end

  def add_vhost(path)
    res = parse_list(rabbitmqctl(:add_vhost, path))
    if res[1]
      "problem adding vhost: #{path} #{res[1]}"
    else
      "successfully added vhost: #{path}"
    end
  end
  
  def add_user(payload)
    if String === payload
      payload = JSON.parse(payload)
    end
    res = parse_list(rabbitmqctl(:add_user, payload['user'], payload['pass']))
    if res[1]
      "problem adding user: #{payload['user']} #{res[1]}"
    else
      "successfully added user: #{payload['user']}"
    end
  end
  
  def change_password(payload)
    if String === payload
      payload = JSON.parse(payload)
    end
    res = parse_list(rabbitmqctl(:change_password, payload['user'], payload['pass']))
    if res[1]
      "problem with change_password user: #{payload['user']} #{res[1]}"
    else
      "successfully changed password user: #{payload['user']}"
    end
  end
  
  def delete_user(payload)
    if String === payload
      payload = JSON.parse(payload)
    end
    res = parse_list(rabbitmqctl(:delete_user, payload['user']))
    if res[1]
      "problem deleting user: #{payload['user']} #{res[1]}"
    else
      "successfully deleted user: #{payload['user']}"
    end
  end
  
  def delete_vhost(path)
    res = parse_list(rabbitmqctl(:delete_vhost, path))
    if res[1]
      "problem deleting vhost: #{path} #{res[1]}"
    else
      "successfully deleted vhost: #{path}"
    end
  end
  
  def rabbitmqctl(*args)
    `rabbitmqctl #{args.join(' ')}`
  end
  
  def parse_list(out)
    res = []
    error = nil
    out.each do |line|
      res << line.chomp unless line =~ /\.\.\./
      error = $1 if line =~ /Error: (.*)/
    end
    [res, error]
  end
end