# you can execute this nanite from the cli.rb command line example app

class Simple < Nanite::Actor

  expose :echo

  def echo(payload)
    "Nanite said #{payload.empty? ? "nothing at all" : payload} @ #{Time.now.to_s}"
  end

end

register('simple', Simple.new)

