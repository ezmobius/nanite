#!/usr/bin/env ruby

puts `rabbitmqctl add_vhost /nanite`

%w[mapper nanite].each do |agent|
  puts `rabbitmqctl add_user #{agent} testing`
  puts `rabbitmqctl map_user_vhost #{agent} /nanite`
end

puts `rabbitmqctl  list_vhosts`
puts `rabbitmqctl  list_users`
puts `rabbitmqctl list_vhost_users /nanite`

