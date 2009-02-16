#!/usr/bin/env ruby

puts `rabbitmqctl add_vhost /nanite`

# create 'mapper' and 'nanite' users, give them each the password 'testing'
%w[mapper nanite].each do |agent|
  puts `rabbitmqctl add_user #{agent} testing`
  puts `rabbitmqctl map_user_vhost #{agent} /nanite`
end

# grant the mapper user the ability to do anything with the /nanite vhost
# the three regex's map to config, write, read permissions respectively
puts `rabbitmqctl set_permissions -p /nanite mapper ".*" ".*" ".*"`

# grant the nanite user more limited permissions on the /nanite vhost
puts `rabbitmqctl set_permissions -p /nanite nanite "^nanite.*" ".*" ".*"`

puts `rabbitmqctl list_users`
puts `rabbitmqctl list_vhosts`
puts `rabbitmqctl list_permissions -p /nanite`