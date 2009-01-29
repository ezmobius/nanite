# you can execute this nanite from the cli.rb command line example app

class Simple < Nanite::Actor
  expose :echo, :time, :gems

  def echo(payload)
    "Nanite said #{payload.empty? ? "nothing at all" : payload} @ #{Time.now.to_s}"
  end

  def time(payload)
    Time.now
  end

  def gems(filter)
    ::Gem.source_index.refresh!.search(filter).flatten.collect {|gemspec| "#{gemspec.name} #{gemspec.version}"}  
  end
end
