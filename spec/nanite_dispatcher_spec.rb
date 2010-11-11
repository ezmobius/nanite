require File.join(File.dirname(__FILE__), 'spec_helper')

class Foo
  include Nanite::Actor
  expose :bar, :index, :i_kill_you
  on_exception :handle_exception

  def index(payload)
    bar(payload)
  end

  def bar(payload)
    ['hello', payload]
  end
  
  def bar2(payload, deliverable)
    deliverable
  end

  def i_kill_you(payload)
    raise RuntimeError.new('I kill you!')
  end

  def handle_exception(method, deliverable, error)
  end
end

class Bar
  include Nanite::Actor
  expose :i_kill_you
  on_exception do |method, deliverable, error|
    @scope = self
    @called_with = [method, deliverable, error]
  end

  def i_kill_you(payload)
    raise RuntimeError.new('I kill you!')
  end
end

class ControlFreak
  include Nanite::Actor

  expose :defuse_bomb, :ack_on_success => true, :requeue_on_failure => true
  expose :defuse_boobytrapped_bomb, :ack_on_success => true, :requeue_on_failure => true
  expose :divide_by_zero, :ack_on_success => true
  expose :make_sandwich

  def sequence
    @sequence ||= []
  end
  
  def defuse_bomb(payload)
    sequence << :method
    :bomb_defused
  end

  def defuse_boobytrapped_bomb(payload)
    sequence << :method
    raise 'Bang'
  end

  def divide_by_zero(payload)
    sequence << :method
    raise 'Division by zero'
  end

  def make_sandwich(payload)
    sequence << :method
    :cheese_and_beetroot
  end
end

# No specs, simply ensures multiple methods for assigning on_exception callback,
# on_exception raises exception when called with an invalid argument.
class Doomed
  include Nanite::Actor
  on_exception do
  end
  on_exception lambda {}
  on_exception :doh
end

# Mock the EventMachine deferrer.
class EMMock
  def self.defer(op = nil, callback = nil)
    callback.call(op.call)
  end
end

describe "Nanite::Dispatcher" do

  before(:each) do
    Nanite::Log.stub!(:info)
    Nanite::Log.stub!(:error)
    amq = mock('amq', :queue => mock('queue', :publish => nil))  
    @header = mock('header', :null_object => true)
    @actor = Foo.new
    @registry = Nanite::ActorRegistry.new
    @registry.register(@actor, nil)
    @dispatcher = Nanite::Dispatcher.new(amq, @registry, Nanite::Serializer.new(:marshal), '0xfunkymonkey', {})
    @dispatcher.evmclass = EMMock
  end

  it "should dispatch a request" do
    req = Nanite::Request.new('/foo/bar', 'you')
    res = @dispatcher.dispatch(@header, req)
    res.should(be_kind_of(Nanite::Result))
    res.token.should == req.token
    res.results.should == ['hello', 'you']
  end

  it "should dispatch the deliverable to actions that accept it" do
    req = Nanite::Request.new('/foo/bar2', 'you')
    res = @dispatcher.dispatch(@header, req)
    res.should(be_kind_of(Nanite::Result))
    res.token.should == req.token
    res.results.should == req
  end

  it "should dispatch a request to the default action" do
    req = Nanite::Request.new('/foo', 'you')
    res = @dispatcher.dispatch(@header, req)
    res.should(be_kind_of(Nanite::Result))
    res.token.should == req.token
    res.results.should == ['hello', 'you']
  end

  it "should handle custom prefixes" do
    @registry.register(Foo.new, 'umbongo')
    req = Nanite::Request.new('/umbongo/bar', 'you')
    res = @dispatcher.dispatch(@header, req)
    res.should(be_kind_of(Nanite::Result))
    res.token.should == req.token
    res.results.should == ['hello', 'you']
  end

  it "should call the on_exception callback if something goes wrong" do
    req = Nanite::Request.new('/foo/i_kill_you', nil)
    @actor.should_receive(:handle_exception).with(:i_kill_you, req, duck_type(:exception, :backtrace))
    @dispatcher.dispatch(@header, req)
  end

  it "should call on_exception Procs defined in a subclass with the correct arguments" do
    actor = Bar.new
    @registry.register(actor, nil)
    req = Nanite::Request.new('/bar/i_kill_you', nil)
    @dispatcher.dispatch(@header, req)
    called_with = actor.instance_variable_get("@called_with")
    called_with[0].should == :i_kill_you
    called_with[1].should == req
    called_with[2].should be_kind_of(RuntimeError)
    called_with[2].message.should == 'I kill you!'
  end

  it "should call on_exception Procs defined in a subclass in the scope of the actor" do
    actor = Bar.new
    @registry.register(actor, nil)
    req = Nanite::Request.new('/bar/i_kill_you', nil)
    @dispatcher.dispatch(@header, req)
    actor.instance_variable_get("@scope").should == actor
  end

  it "should log error if something goes wrong" do
    Nanite::Log.should_receive(:error)
    req = Nanite::Request.new('/foo/i_kill_you', nil)
    @dispatcher.dispatch(@header, req)
  end

  it "can acknowledge receipt of the message before delivering the message to the method" do
    actor = ControlFreak.new
    @registry.register(actor, nil)
    req = Nanite::Request.new('/control_freak/make_sandwich', nil)
    @header.should_receive(:ack) { actor.sequence << :ack }
    @dispatcher.dispatch(@header, req)
    actor.sequence.should == [:ack, :method]
  end

  it "can acknowledge receipt of the message after delivering the message to the method" do
    actor = ControlFreak.new
    @registry.register(actor, nil)
    req = Nanite::Request.new('/control_freak/defuse_bomb', nil)
    @header.should_receive(:ack) { actor.sequence << :ack }
    @dispatcher.dispatch(@header, req)
    actor.sequence.should == [:method, :ack]
  end

  it "can requeue the message if an exception is raised while processing a message" do
    actor = ControlFreak.new
    @registry.register(actor, nil)
    req = Nanite::Request.new('/control_freak/defuse_boobytrapped_bomb', nil)
    @header.should_receive(:reject) { actor.sequence << :reject }.should_not_receive(:ack)
    @dispatcher.dispatch(@header, req)
    actor.sequence.should == [:method, :reject]
  end

  it "can leave the message to time out if an exception is raised while processing the message" do
    actor = ControlFreak.new
    @registry.register(actor, nil)
    req = Nanite::Request.new('/control_freak/divide_by_zero', nil)
    @header.should_not_receive(:reject).should_not_receive(:ack)
    @dispatcher.dispatch(@header, req)
    actor.sequence.should == [:method]
  end
end # Nanite::Dispatcher
