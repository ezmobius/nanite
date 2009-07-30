require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::JobWarden do

  describe "Creating a new Job" do

    before(:each) do
      @serializer = mock("Serializer")
      @warden = Nanite::JobWarden.new(@serializer)

      @request = mock("Request")
      @targets = mock("Targets")
      @job = mock("Job", :token => "3faba24fcc")
    end

    it "should instantiate a new Job" do
      Nanite::Job.should_receive(:new).with(@request, @targets, nil, nil).and_return(@job)
      @warden.new_job(@request, @targets)
    end

    it "should add the job to the job list" do
      Nanite::Job.should_receive(:new).with(@request, @targets, nil, nil).and_return(@job)
      @warden.jobs.size.should == 0
      @warden.new_job(@request, @targets)
      @warden.jobs.size.should == 1
      @warden.jobs["3faba24fcc"].should == @job
    end

    it "return the newly crated job" do
      Nanite::Job.should_receive(:new).with(@request, @targets, nil, nil).and_return(@job)
      @warden.new_job(@request, @targets).should == @job
    end

  end # Creating a new Job

  describe "Processing an intermediate message" do
    before(:each) do
      @intm_handler = lambda {|arg1, arg2, arg3| puts 'ehlo'}
      @message = mock("Message", :token => "3faba24fcc", :from => 'nanite-agent')
      @serializer = mock("Serializer", :load => @message)
      @warden = Nanite::JobWarden.new(@serializer)
      @job = Nanite::Job.new(stub("request", :token => "3faba24fcc"), [], @intm_handler)
      @job.instance_variable_set(:@pending_keys, ["defaultkey"])
      @job.instance_variable_set(:@intermediate_state, {"nanite-agent" => {"defaultkey" => [1]}})
      @warden.jobs[@job.token] = @job
      Nanite::Log.stub!(:debug)
      Nanite::Log.stub!(:error)
    end
    
    it "should call the intermediate handler with three parameters" do
      @intm_handler.should_receive(:call).with("defaultkey", "nanite-agent", 1)
      @warden.process(@message)
    end
    
    it "should call the intermediate handler with four parameters" do
      @intm_handler.stub!(:arity).and_return(4)
      @intm_handler.should_receive(:call).with("defaultkey", "nanite-agent", 1, @job)
      @warden.process(@message)
    end
    
    it "should not call the intermediate handler when it can't be found for the specified key" do
      @intm_handler.should_not_receive(:call)
      @job.instance_variable_set(:@intermediate_handler, nil)
      @warden.process(@message)
    end
    
    it "should call the intermediate handler with one parameter which needs to be the result" do
      @intm_handler.should_receive(:call).with(1, @job)
      @intm_handler.stub!(:arity).and_return(2)
      @warden.process(@message)
    end
  end
  
  describe "Processing a Message" do

    before(:each) do
      @message = mock("Message", :token => "3faba24fcc")
      @warden = Nanite::JobWarden.new(@serializer)
      @job = mock("Job", :token => "3faba24fcc", :process => true, :completed? => false, :results => 42, :pending_keys => [], :intermediate_handler => true)

      Nanite::Log.stub!(:debug)
    end

    it "should hand over processing to job" do
      Nanite::Job.stub!(:new).and_return(@job)
      @job.should_receive(:process).with(@message)

      @warden.new_job("request", "targets")
      @warden.process(@message)
    end

    it "should delete job from jobs after completion" do
      Nanite::Job.stub!(:new).and_return(@job)
      @job.should_receive(:process).with(@message)
      @job.should_receive(:completed?).and_return(true)
      @job.should_receive(:completed).and_return(nil)

      @warden.jobs["3faba24fcc"].should be_nil
      @warden.new_job("request", "targets")
      @warden.jobs["3faba24fcc"].should == @job
      @warden.process(@message)
      @warden.jobs["3faba24fcc"].should be_nil
    end

    it "should call completed block after completion" do
      completed_block = mock("Completed", :arity => 1, :call => true)

      Nanite::Job.stub!(:new).and_return(@job)
      @job.should_receive(:process).with(@message)
      @job.should_receive(:completed?).and_return(true)
      @job.should_receive(:completed).exactly(3).times.and_return(completed_block)

      @warden.new_job("request", "targets")
      @warden.process(@message)
    end

    it "should pass in job result if arity of completed block is one" do
      completed_block = mock("Completed")

      Nanite::Job.stub!(:new).and_return(@job)
      @job.should_receive(:process).with(@message)
      @job.should_receive(:completed?).and_return(true)
      @job.should_receive(:completed).exactly(3).times.and_return(completed_block)
      @job.should_receive(:results).and_return("the job result")
      completed_block.should_receive(:arity).and_return(1)
      completed_block.should_receive(:call).with("the job result")

      @warden.new_job("request", "targets")
      @warden.process(@message)
    end

    it "should pass in job result and job if arity of completed block is two" do
      completed_block = mock("Completed")

      Nanite::Job.stub!(:new).and_return(@job)
      @job.should_receive(:process).with(@message)
      @job.should_receive(:completed?).and_return(true)
      @job.should_receive(:completed).exactly(3).times.and_return(completed_block)
      @job.should_receive(:results).and_return("the job result")
      completed_block.should_receive(:arity).and_return(2)
      completed_block.should_receive(:call).with("the job result", @job)

      @warden.new_job("request", "targets")
      @warden.process(@message)
    end

  end # Processing a Message

end # Nanite::JobWarden


describe Nanite::Job do

  describe "Creating a Job" do

    before(:each) do
      @request = mock("Request", :token => "af534ceaaacdcd")
    end

    it "should initialize the request" do
      job = Nanite::Job.new(@request, nil, nil)
      job.request.should == @request
    end

    it "should initialize the targets" do
      job = Nanite::Job.new(@request, "targets", nil)
      job.targets.should == "targets"
    end

    it "should initialize the job token to the request token" do
      job = Nanite::Job.new(@request, nil, nil)
      job.token.should == "af534ceaaacdcd"
    end

    it "should initialize the results to an empty hash" do
      job = Nanite::Job.new(@request, nil, nil)
      job.results.should == {}
    end

    it "should initialize the intermediate state to an empty hash" do
      job = Nanite::Job.new(@request, nil, nil)
      job.intermediate_state.should == {}
    end

    it "should initialize the job block" do
      job = Nanite::Job.new(@request, nil, nil, "my block")
      job.completed.should == "my block"
    end

  end # Creating a new Job


  describe "Processing a Message" do

    before(:each) do
      @request = mock("Request", :token => "feeefe132")
    end

    it "should set the job result (for sender) to the message result for 'final' status messages" do
      job = Nanite::Job.new(@request, [], nil)
      message = Nanite::Result.new('token', 'to', 'results', 'from')
      job.results.should == {}
      job.process(message)
      job.results.should == { 'from' => 'results' }
    end

    it "should delete the message sender from the targets for 'final' status messages" do
      job = Nanite::Job.new(@request, ['from'], nil)
      message = Nanite::Result.new('token', 'to', 'results', 'from')
      job.targets.should == ['from']
      job.process(message)
      job.targets.should == []
    end

    it "should set the job result (for sender) to the message result for 'intermediate' status messages" do
      job = Nanite::Job.new(@request, ['from'], nil)
      message = Nanite::IntermediateMessage.new('token', 'to', 'from', 'messagekey', 'message')
      job.process(message)
      job.intermediate_state.should == { 'from' => { 'messagekey' => ['message'] } }
    end

    it "should not delete the message sender from the targets for 'intermediate' status messages" do
      job = Nanite::Job.new(@request, ['from'], nil)
      message = Nanite::IntermediateMessage.new('token', 'to', 'from', 'messagekey', 'message')
      job.targets.should == ['from']
      job.process(message)
      job.targets.should == ['from']
    end

  end # Processing a Message


  describe "Completion" do

    before(:each) do
      @request = mock("Request", :token => "af534ceaaacdcd")
    end

    it "should be true is targets are empty" do
      job = Nanite::Job.new(@request, {}, nil)
      job.completed?.should == true
    end

    it "should be false is targets are not empty" do
      job = Nanite::Job.new(@request, { :a => 1 }, nil)
      job.completed?.should == false
    end

  end # Completion

end # Nanite::Job
