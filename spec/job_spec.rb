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

end # Nanite::JobWarden
