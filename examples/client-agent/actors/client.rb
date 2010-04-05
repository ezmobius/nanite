# you can execute this nanite from the cli.rb command line example app
# you should first run a simpleagent
# this example will send a request to the /simple/echo operation

class Client
  include Nanite::Actor
  expose :delegate

  def delegate(payload)
    nanite, payload = payload
    request(nanite, payload) do |res|
      p "Got response '#{res.inspect}' from #{nanite}"
    end
    "sent request to #{nanite} with payload '#{payload}'"
  end
end
