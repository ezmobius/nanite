require 'nanite/actor'
require 'nanite/dispatcher'

class GemRunner < Nanite::Actor
  provides '/gem'
  
  def list(filter)
    ::Gem.source_index.refresh!.search(filter).flatten.collect {|gemspec| "#{gemspec.name} #{gemspec.version}"}  
  end
end 



def run_event_loop(threaded = true)
  runner = proc do
    EM.run {
      name, *resources = ARGV
      Nanite.identity  = name
      Nanite.default_resources = resources.map{|r| Nanite::Resource.new(r)}
      unless name.strip == 'client'
        Nanite::Dispatcher.register(GemRunner.new)
      end
      Nanite.mapper.register name, Nanite::Dispatcher.all_resources do |r|
        puts r
      end  
      
      Nanite.amq.queue(Nanite.identity).subscribe{ |msg|
        Nanite::Dispatcher.handle(Marshal.load(msg))
      }
    }
  end
  if threaded
    Thread.new { runner.call }
  else
    runner.call
  end      
end  


def op(type, payload, *resources)
  op = Nanite::Op.new(type, payload, *resources)
  Nanite.mapper.route(op) do |res|
    p res
  end
end

if ARGV.first.strip == 'client'
  run_event_loop
  ARGV.clear
  running = true
  while running
    puts "nanite>"
    type, payload, *resources = gets.split(' ')
    if type == 'die'
      running = false 
      next
    end
    if type.strip == 'discover'
      Nanite.mapper.discover(resources.map{|r| Nanite::Resource.new(r)}) do |tok|
        p tok
      end
    else  
      op(type, payload, *resources)
    end
  end  
else
  run_event_loop false
end  
