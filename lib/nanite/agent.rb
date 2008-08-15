require 'nanite/actor'
require 'nanite/dispatcher'
class GemRunner < Nanite::Actor
  provides '/gem'
  
  def list(filter)
    ::Gem.source_index.refresh!.search(filter).flatten.collect {|gemspec| "#{gemspec.name} #{gemspec.version}"}  
  end
end 

class Mock < Nanite::Actor
  provides '/mock'
  
  def list(filter)
    [1,2,3]
  end
end

def stress(times)
  t = Time.now
  times.times do
     p get_result(op('list', 'dm', '/mock'))
  end
  puts Time.now - t
end

def op(type, payload, *resources, &blk)
  Nanite.op(type, payload, *resources, &blk)
end

def get_result(tok)
  until r = Nanite.results.delete(tok)
    sleep 0.00001
  end
  r
end
