class Gems < Nanite::Actor
  expose :list
  
  def list(filter)
    ::Gem.source_index.refresh!.search(filter).flatten.collect {|gemspec| "#{gemspec.name} #{gemspec.version}"}  
  end
end

Nanite::Dispatcher.register(Gems.new)

#Nanite.subscribe_to_files