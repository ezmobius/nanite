require 'rubygems'
require 'nanite'
require 'nanite/mapper'

# you need raggi's patched async version of thin:
# git clone git://github.com/raggi/thin.git
# cd thin
# git branch async
# git checkout async
# git pull origin async_for_rack
# rake install
# thin -R async_rack_front.ru -p 4000 start
 
class AsyncApp
  
  AsyncResponse = [-1, {}, []].freeze
    
  def call(env)
    
    env.delete('rack.errors')
    input = env.delete('rack.input')
    async_callback = env.delete('async.callback')
    
    Nanite.request('/rack_worker/call', env, :selector => :random, :timeout => 15) do |response| 
      if response
        async_callback.call response.values.first
      else
        async_callback.call [500, {'Content-Type' => 'text/html'}, "Request Timeout"]
      end    
    end
    AsyncResponse
  end
  
end
 
Thread.new do
  until EM.reactor_running?  
    sleep 1
  end
  AMQP.start :host => 'localhost', :user => 'mapper', :pass => 'testing',
             :vhost => '/nanite'
  Nanite.identity = "mapper"
  Nanite.mapper = Nanite::Mapper.new(15)
end

run AsyncApp.new
