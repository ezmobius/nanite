#!/usr/bin/env ruby

puts `rabbitmqctl add_vhost /nanite`

%w[mapper nanite].each do |agent|
  puts `rabbitmqctl add_user #{agent} testing`
  puts `rabbitmqctl map_user_vhost #{agent} /nanite`
end

puts `scripts/rabbitmqctl set_permissions -p /nanite mapper '.*' ".*"`
puts `scripts/rabbitmqctl set_permissions -p /nanite nanite '^nanite.*' ".*"`

puts `rabbitmqctl  list_vhosts`
puts `rabbitmqctl  list_users`
puts `rabbitmqctl  list_permissions`
puts `rabbitmqctl list_vhost_users /nanite`

