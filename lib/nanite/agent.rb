require 'nanite/actor'
require 'nanite/dispatcher'
class GemRunner < Nanite::Actor
  provides '/gem'
  
  def list(filter)
    ::Gem.source_index.refresh!.search(filter).flatten.collect {|gemspec| "#{gemspec.name} #{gemspec.version}"}  
  end
end 



def stress(times, &blk)
  t = Time.now
  times.times do
    op('list', 'dm', '/mock', &blk)
  end
  puts Time.now - t
end

def op(type, payload, *resources, &blk)
  Nanite.op(type, payload, *resources, &blk)
end


def do_pings
  Nanite.mapper.send_pings
end