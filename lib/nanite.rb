module Nanite
  class << self
    attr_accessor :identity
    def gen_token
      values = [
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x1000000),
        rand(0x1000000),
      ]
      "%04x%04x%04x%04x%04x%06x%06x" % values
    end
    
    def queue(q)
      @queues ||= Hash.new { |h,k| h[k] = Queue.new }
      @queues[q]
    end
        
    def delete_queue(q)
      @queues.delete(q)
    end
  end  
end  