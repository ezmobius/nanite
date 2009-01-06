class RackWorker < Nanite::Actor
  
  expose :call
  
  def initialize(app)
    @app = app
  end
  
  def call(env)
    @app.call(env)
  end
  
end

app = Proc.new do |env|
  [200, {'Content-Type'=>'text/html'}, "hello world!"]
end  

register(RackWorker.new(app), 'rack')

