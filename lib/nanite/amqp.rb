class MQ
  class Queue
    
    def recover
      @mq.callback{
        @mq.send Protocol::Basic::Recover.new({ :requeue => 0 })
      }
      self
    end
  end
end

