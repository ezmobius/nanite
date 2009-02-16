require File.dirname(__FILE__) + '/spec_helper'
require 'nanite'

class WebDocumentImporter < Nanite::Actor
  expose :import, :cancel
  
  def import
    1
  end
  def cancel
    0
  end
end

module Actors
  class ComedyActor < Nanite::Actor
    expose :fun_tricks
    def fun_tricks
      :rabbit_in_the_hat
    end
  end
end

describe Nanite::Actor do
  describe ".default_prefix" do
    it "is calculated as default prefix as const path of class name" do
      Nanite::Actor.default_prefix.should       == "nanite/actor"
      Actors::ComedyActor.default_prefix.should == "actors/comedy_actor"
      WebDocumentImporter.default_prefix.should == "web_document_importer"
    end    
  end
  
  describe ".provides_for(prefix)" do
    before :each do
      @provides = Actors::ComedyActor.provides_for("money")
    end
    it "returns an array" do
      @provides.should be_kind_of(Array)
    end

    it "maps exposed service methods to prefix" do
      @provides.should == ["/money/fun_tricks"]
      wdi_provides = WebDocumentImporter.provides_for("webfiles")
      wdi_provides.should include("/webfiles/import")
      wdi_provides.should include("/webfiles/cancel")
    end
  end
end

describe Nanite::ActorRegistry do
  before(:each) do
    log = mock('log', :info => nil)
    @registry = Nanite::ActorRegistry.new(log)
  end

  it "should know about all services" do
    @registry.register(WebDocumentImporter.new, nil)
    @registry.register(Actors::ComedyActor.new, nil)
    @registry.services.should == ["/actors/comedy_actor/fun_tricks", "/web_document_importer/import", "/web_document_importer/cancel"]
  end

  it "should not register anything except Nanite::Actor" do
    lambda{@registry.register(String.new, nil)}.should raise_error(ArgumentError)
  end

  it "should register an actor" do
    importer = WebDocumentImporter.new
    @registry.register(importer, nil)
    @registry.actors['web_document_importer'].should == importer
  end

  it "should handle actors registered with a custom prefix" do
    importer = WebDocumentImporter.new
    @registry.register(importer, 'monkey')
    @registry.actors['monkey'].should == importer
  end
end