class Mock < Nanite::Actor
  expose :list
    
  def list(payload)
    p "got request"
    [1,2,3]
  end
end

Nanite::Dispatcher.register(Mock.new)
                 
                 
                 