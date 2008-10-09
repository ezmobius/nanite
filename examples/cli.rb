require 'rubygems'
require 'nanite'
require 'nanite/mapper'

Nanite.identity = Nanite.gen_token

EM.run {
  AMQP.start :host => 'localhost', :user => 'mapper', :pass => 'testing',
             :vhost => '/nanite'
  Nanite.mapper = Nanite::Mapper.new(15)
  Nanite.push_to_exchange("/mock/list", 'foobar')
  EM.add_timer(1){EM.stop_event_loop}
}
