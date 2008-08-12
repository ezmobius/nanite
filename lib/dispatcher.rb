module Nanite
  class Dispatcher
    class << self
      def register(actor_instance)
        (@actors ||= []) << actor_instance
      end
      
      def all_resources
        (Nanite.default_resources + @actors.map {|a| a.provides }.flatten).uniq
      end
  
      def candidates(resources)
        (@actors||[]).select {|actor| can_provide?(resources, actor.provides)}
      end
  
      def dispatch_op(op)
        actors = candidates(op.resources)
        res = []
        actors.each do |actor|
          begin
            res << actor.send(op.type, op.payload)
          rescue Exception => e
            res << "Dispatch Error: #{e.message}"
          end
        end
        Nanite::Result.new(op.token, op.from, Nanite.identity,  res.size == 1 ? res.first : res)
      end    
      
      def handle(packet)
        case packet
        when Nanite::Result
          p packet.results
        when Nanite::Op
          p "got op", packet
          result = dispatch_op(packet)
          Nanite.amq.queue('reducer').publish(Marshal.dump(result))
        end
      end
      
      def can_provide?(required_resources, provided_resources)
        results = []
        required_resources.each do |req|
          accepted = false
          provided_resources.each do |prov|
            if req >= prov
              accepted = true
              break 
            end
          end
          results << accepted  
        end
        results.all? {|r| r }
      end
    end    
  end

end