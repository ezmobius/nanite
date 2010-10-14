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
  before(:each) do
    reset_broker
    @offline = Nanite::Mapper::OfflineQueue.new({})
    @offline.run
  end
  
  it "should consume messages off the offline queue" do
  end

  it "should ack messages"
end
