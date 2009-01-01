class Simple < Nanite::Actor

  expose :hello

  def hello(payload)
    "hello nanite"
  end

end

Nanite::Dispatcher.register(Simple.new)

