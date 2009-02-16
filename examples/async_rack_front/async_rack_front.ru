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

class NaniteApp

  AsyncResponse = [-1, {}, []].freeze

  def call(env)
    mapper = Nanite::Mapper.start
    def call(env)
      env.delete('rack.errors')
      input = env.delete('rack.input')
      async_callback = env.delete('async.callback')

      mapper.request('/rack/call', env, :selector => :random, :timeout => 15) do |response|
        if response
          async_callback.call response.values.first
        else
          async_callback.call [500, {'Content-Type' => 'text/html'}, "Request Timeout"]
        end
      end
      AsyncResponse
    end
    [200, {'Content-Type' => 'text/html'}, "warmed up nanite mapper"]
  end
end

run NaniteApp.new
