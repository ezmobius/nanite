require File.dirname(__FILE__) + '/spec_helper'
require 'nanite'

describe "Serializer:" do

  describe "Format" do

    it "supports JSON format" do
      [ :json, "json" ].each do |format|
        serializer = Nanite::Serializer.new(format)
        serializer.instance_eval { @serializers.first }.should == JSON
      end
    end

    it "supports Marshal format" do
      [ :marshal, "marshal" ].each do |format|
        serializer = Nanite::Serializer.new(format)
        serializer.instance_eval { @serializers.first }.should == Marshal
      end
    end

    it "supports YAML format" do
      [ :yaml, "yaml" ].each do |format|
        serializer = Nanite::Serializer.new(format)
        serializer.instance_eval { @serializers.first }.should == YAML
      end
    end

    it "should default to Marshal format if not specified" do
      serializer = Nanite::Serializer.new
      serializer.instance_eval { @serializers.first }.should == Marshal
      serializer = Nanite::Serializer.new(nil)
      serializer.instance_eval { @serializers.first }.should == Marshal
    end

  end

  describe "Serialization of Packet" do

    it "should try all three supported formats (JSON, Marshal, YAML)" do
      serialized_packet = mock("Packet")
      # Nanite::Serializer tries serializers in hash order which
      # is dependent on hash value of key and capacity
      # which is platform/version dependent
      serializers = {:json => JSON, :marshal => Marshal, :yaml => YAML}.values.clone
      puts serializers.inspect
      serializers[0].should_receive(:dump).with("hello").and_raise(StandardError)
      serializers[1].should_receive(:dump).with("hello").and_raise(StandardError)
      serializers[2].should_receive(:dump).with("hello").and_return(serialized_packet)

      serializer = Nanite::Serializer.new
      serializer.dump("hello")
    end

    it "should raise SerializationError if packet could not be serialized" do
      JSON.should_receive(:dump).with("hello").and_raise(StandardError)
      Marshal.should_receive(:dump).with("hello").and_raise(StandardError)
      YAML.should_receive(:dump).with("hello").and_raise(StandardError)

      serializer = Nanite::Serializer.new
      lambda { serializer.dump("hello") }.should raise_error(Nanite::Serializer::SerializationError)
    end

    it "should return serialized packet" do
      serialized_packet = mock("Packet")
      Marshal.should_receive(:dump).with("hello").and_return(serialized_packet)

      serializer = Nanite::Serializer.new(:marshal)
      serializer.dump("hello").should == serialized_packet
    end

  end

  describe "De-Serialization of Packet" do

    it "should try all three supported formats (JSON, Marshal, YAML)" do
      deserialized_packet = mock("Packet")
      # Nanite::Serializer tries serializers in hash order which
      # is dependent on hash value of key and capacity
      # which is platform/version dependent
      serializers = {:json => JSON, :marshal => Marshal, :yaml => YAML}.values.clone
      puts serializers.inspect
      serializers[0].should_receive(:load).with("olleh").and_raise(StandardError)
      serializers[1].should_receive(:load).with("olleh").and_raise(StandardError)
      serializers[2].should_receive(:load).with("olleh").and_return(deserialized_packet)

      serializer = Nanite::Serializer.new
      serializer.load("olleh").should == deserialized_packet
    end

    it "should raise SerializationError if packet could not be de-serialized" do
      JSON.should_receive(:load).with("olleh").and_raise(StandardError)
      Marshal.should_receive(:load).with("olleh").and_raise(StandardError)
      YAML.should_receive(:load).with("olleh").and_raise(StandardError)

      serializer = Nanite::Serializer.new
      lambda { serializer.load("olleh") }.should raise_error(Nanite::Serializer::SerializationError)
    end

    it "should return de-serialized packet" do
      deserialized_packet = mock("Packet")
      Marshal.should_receive(:load).with("olleh").and_return(deserialized_packet)

      serializer = Nanite::Serializer.new(:marshal)
      serializer.load("olleh").should == deserialized_packet
    end

  end

end
