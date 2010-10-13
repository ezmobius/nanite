require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

require 'moqueue'

overload_amqp

describe Nanite::Mapper::Requests do
  before(:each) do
    reset_broker
    @requests = Nanite::Mapper::Requests.new
    @requests.run
    @mq = mock_queue("request")
    @message = Nanite::Serializer.new('yaml').dump(Nanite::Request.new('/agent/log', "message"))
  end

  describe "Handling requests from agents" do
    it "should forward them to another agent" do
      @mq.publish(@message)
    end
  end
end
