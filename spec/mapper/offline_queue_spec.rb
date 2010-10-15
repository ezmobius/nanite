require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'moqueue'
overload_amqp

module EventMachine
  def self.add_periodic_timer(timeout, &blk)
    blk.call
  end
end

class Moqueue::MockQueue
  def recover
  end
end

describe Nanite::Mapper::OfflineQueue do
  include Nanite::Helpers::StateHelper

  before(:each) do
    reset_broker
    @offline = Nanite::Mapper::OfflineQueue.new({})
    @offline.run
    @mq = mock_queue("mapper-offline")
    @push = Nanite::Push.new('nanite-1234', "message")
    @serializer = Nanite::Serializer.new('yaml')
    @message = @serializer.dump(@push)
    setup_state(nil)
  end
  
  it "should consume messages off the offline queue" do
    @mq.publish(@message)
    @mq.should have_received(@message)
  end

  it "should ack messages"
end
