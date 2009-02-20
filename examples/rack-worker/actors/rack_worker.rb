class RackWorker
  include Nanite::Actor
  expose :call

  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  end
end
