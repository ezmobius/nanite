
Shoes.setup do
  gem 'eventmachine'
  gem 'amqp'
end

require File.dirname(__FILE__) + "/../nanite"
require File.dirname(__FILE__) + "/../nanite/agent"

name, resources = 'shoes', []
Nanite.identity  = name
Nanite.default_resources = resources.map{|r| Nanite::Resource.new(r)}
ARGV.clear
Thread.new do
  EM.run do
    Shoes.p "running event loop"
    Nanite.run_event_loop
  end
end

Shoes.app do
  background "#eee"
  flow do
    image Nanite.root + "/eylogo.gif"
    para "op"
    @op = edit_line :width => 40, :text => "list"
    para "resources"
    @resources = edit_line :width => 120, :text => "/mock"
    para "payload"
    @payload = edit_line :width => 120
    
    stack :margin => 10 do
      button "Dispatch" do
        @res.clear { para "running..." }
        Shoes.p [@op.text, @resources.text, @payload.text]
        Nanite.op(@op.text, @payload.text, *@resources.text.split(/,/)) do |res|
          Shoes.p res
          formatted = ""
          res.each do |a, res|
            formatted << "#{a}: #{res.inspect}\n"
          end  
          @res.clear { para(formatted ) }
        end  
      end
    end
    

    
    @res = stack { para "results" }
  end
end
