class Mock < Nanite::Actor
  
  expose :list
    
  def list(filter)
    [1,2,3]
  end
end

Nanite::Dispatcher.register(Mock.new)
