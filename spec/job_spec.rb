require File.dirname(__FILE__) + '/spec_helper'
require 'nanite'

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
      Nanite::Job.should_receive(:new).with(@request, @targets, nil).and_return(@job)
      @warden.new_job(@request, @targets)
    end

    it "should add the job to the job list" do
      Nanite::Job.should_receive(:new).with(@request, @targets, nil).and_return(@job)
      @warden.jobs.size.should == 0
      @warden.new_job(@request, @targets)
      @warden.jobs.size.should == 1
      @warden.jobs["3faba24fcc"].should == @job
    end

    it "return the newly crated job" do
      Nanite::Job.should_receive(:new).with(@request, @targets, nil).and_return(@job)
      @warden.new_job(@request, @targets).should == @job
    end

  end # Creating a new Job


  describe "Processing a Message" do

    before(:each) do
      @message = mock("Message", :token => "3faba24fcc")
      @serializer = mock("Serializer", :load => @message)
      @warden = Nanite::JobWarden.new(@serializer)
      @job = mock("Job", :token => "3faba24fcc", :process => true, :completed? => false, :results => 42)

      Nanite::Log.stub!(:debug)
    end

    it "should de-serialize the message" do
      @serializer.should_receive(:load).with("the serialized message").and_return(@message)
      @warden.process("the serialized message")
    end

    it "should log debug message about message to be processed" do
      Nanite::Log.should_receive(:debug)
      @warden.process("the serialized message")
    end

    it "should hand over processing to job" do
      Nanite::Job.stub!(:new).and_return(@job)
      @job.should_receive(:process).with(@message)

      @warden.new_job("request", "targets")
      @warden.process("the serialized message")
    end

    it "should delete job from jobs after completion" do
      Nanite::Job.stub!(:new).and_return(@job)
      @job.should_receive(:process).with(@message)
      @job.should_receive(:completed?).and_return(true)
      @job.should_receive(:completed).and_return(nil)

      @warden.jobs["3faba24fcc"].should be_nil
      @warden.new_job("request", "targets")
      @warden.jobs["3faba24fcc"].should == @job
      @warden.process("the serialized message")
      @warden.jobs["3faba24fcc"].should be_nil
    end

    it "should call completed block after completion" do
      completed_block = mock("Completed", :arity => 1, :call => true)

      Nanite::Job.stub!(:new).and_return(@job)
      @job.should_receive(:process).with(@message)
      @job.should_receive(:completed?).and_return(true)
      @job.should_receive(:completed).exactly(3).times.and_return(completed_block)

      @warden.new_job("request", "targets")
      @warden.process("the serialized message")
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
      @warden.process("the serialized message")
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
      @warden.process("the serialized message")
    end

  end # Processing a Message

end # Nanite::JobWarden
