class Mock < Nanite::Actor
  expose :list
    
  def list(payload)
    [1,2,3]
  end
end

Nanite::Dispatcher.register(Mock.new)
                 
                 
                 