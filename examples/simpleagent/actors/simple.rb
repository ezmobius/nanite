# you can execute this nanite from the cli.rb command line example app

class Simple
  include Nanite::Actor
  expose :echo, :time, :gems, :yielding, :delayed

  def echo(payload)
    "Nanite said #{payload.empty? ? "nothing at all" : payload} @ #{Time.now.to_s}"
  end

  def time(payload)
    Time.now
  end

  def yielding(payload)
    3.times do
      yield :random, "%06x%06x" % [ rand(0x1000000), rand(0x1000000) ]
    end
    [1,2,3].each do |num|
      yield :testkey, num
    end
    ["a","b","c"].each do |val|
      yield val
    end
    "Nanite said #{payload.empty? ? "nothing at all" : payload} @ #{Time.now.to_s}"
  end

  def delayed(payload)
    3.times do
      yield :random, "%06x%06x" % [ rand(0x1000000), rand(0x1000000) ]
      sleep 1
    end
    [1,2,3].each do |num|
      yield :testkey, num
      sleep 2
    end
    ["a","b","c"].each do |val|
      yield val
    end
    "Nanite said #{payload.empty? ? "nothing at all" : payload} @ #{Time.now.to_s}"
  end

  def gems(filter)
    ::Gem.source_index.refresh!.search(filter).flatten.collect {|gemspec| "#{gemspec.name} #{gemspec.version}"}  
  end
end
