require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::Actor do
  class ::WebDocumentImporter
    include Nanite::Actor
    expose :import, :cancel

    def import
      1
    end
    def cancel
      0
    end
    def continue
      1
    end
  end

  module ::Actors
    class ComedyActor
      include Nanite::Actor
      expose :fun_tricks
      def fun_tricks
        :rabbit_in_the_hat
      end
    end
  end

  class ::Actors::InvalidActor
    include Nanite::Actor
    expose :non_existing
  end
  
  describe ".expose" do
    before :each do
      @exposed = WebDocumentImporter.instance_variable_get(:@exposed).dup
    end
    
    after :each do
      WebDocumentImporter.instance_variable_set(:@exposed, @exposed)
    end
    
    
    it "should single expose method only once" do
      3.times { WebDocumentImporter.expose(:continue) }
      WebDocumentImporter.provides_for("webfiles").should == ["/webfiles/import", "/webfiles/cancel", "/webfiles/continue"]
    end
  end
  
  describe ".default_prefix" do
    it "is calculated as default prefix as const path of class name" do
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
    
    it "should not include methods not existing in the actor class" do
      Actors::InvalidActor.provides_for("money").should_not include("/money/non_existing")
    end
  end
end
