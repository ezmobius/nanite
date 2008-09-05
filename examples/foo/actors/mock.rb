class Mock < Nanite::Actor
  provides '/mock'
  
  def list(filter)
    [1,2,3]
  end
end

Nanite::Dispatcher.register(Mock.new)

Nanite.subscribe_to_files