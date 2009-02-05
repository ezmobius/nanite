require File.dirname(__FILE__) + '/spec_helper'
require 'nanite/packets'
require 'json'

describe "Packet: FileStart" do
  it "should dump/load as JSON objects" do
    packet = Nanite::FileStart.new('foo.txt', 'somewhere/foo.txt', '0xdeadbeef')
    packet2 = JSON.parse(packet.to_json)
    packet.filename.should == packet2.filename
    packet.dest.should == packet2.dest
    packet.token.should == packet2.token
  end
  
  it "should dump/load as Marshalled ruby objects" do
    packet = Nanite::FileStart.new('foo.txt', 'somewhere/foo.txt', '0xdeadbeef')
    packet2 = Marshal.load(Marshal.dump(packet))
    packet.filename.should == packet2.filename
    packet.dest.should == packet2.dest
    packet.token.should == packet2.token
  end
end

describe "Packet: FileEnd" do
  it "should dump/load as JSON objects" do
    packet = Nanite::FileEnd.new('0xdeadbeef', 'metadata')
    packet2 = JSON.parse(packet.to_json)
    packet.meta.should == packet2.meta
    packet.token.should == packet2.token
  end
  
  it "should dump/load as Marshalled ruby objects" do
    packet = Nanite::FileEnd.new('0xdeadbeef', 'metadata')
    packet2 = Marshal.load(Marshal.dump(packet))
    packet.meta.should == packet2.meta
    packet.token.should == packet2.token
  end
end

describe "Packet: FileChunk" do
  it "should dump/load as JSON objects" do
    packet = Nanite::FileChunk.new('chunk','0xdeadbeef')
    packet2 = JSON.parse(packet.to_json)
    packet.chunk.should == packet2.chunk
    packet.token.should == packet2.token
  end
  
  it "should dump/load as Marshalled ruby objects" do
    packet = Nanite::FileChunk.new('chunk','0xdeadbeef')
    packet2 = Marshal.load(Marshal.dump(packet))
    packet.chunk.should == packet2.chunk
    packet.token.should == packet2.token
  end
end

describe "Packet: Request" do
  it "should dump/load as JSON objects" do
    packet = Nanite::Request.new('/some/foo', 'payload', :from => 'from', :token => '0xdeadbeef', :reply_to => 'reply_to')
    packet2 = JSON.parse(packet.to_json)
    packet.type.should == packet2.type
    packet.payload.should == packet2.payload
    packet.from.should == packet2.from
    packet.token.should == packet2.token
    packet.reply_to.should == packet2.reply_to
  end
  
  it "should dump/load as Marshalled ruby objects" do
    packet = Nanite::Request.new('/some/foo', 'payload', :from => 'from', :token => '0xdeadbeef', :reply_to => 'reply_to')
    packet2 = Marshal.load(Marshal.dump(packet))
    packet.type.should == packet2.type
    packet.payload.should == packet2.payload
    packet.from.should == packet2.from
    packet.token.should == packet2.token
    packet.reply_to.should == packet2.reply_to  
  end
end


describe "Packet: Result" do
  it "should dump/load as JSON objects" do
    packet = Nanite::Result.new('0xdeadbeef', 'to', 'results', 'from')
    packet2 = JSON.parse(packet.to_json)
    packet.token.should == packet2.token
    packet.to.should == packet2.to
    packet.results.should == packet2.results
    packet.from.should == packet2.from
  end
  
  it "should dump/load as Marshalled ruby objects" do
    packet = Nanite::Result.new('0xdeadbeef', 'to', 'results', 'from')
    packet2 = Marshal.load(Marshal.dump(packet))
    packet.token.should == packet2.token
    packet.to.should == packet2.to
    packet.results.should == packet2.results
    packet.from.should == packet2.from  
  end
end

describe "Packet: Register" do
  it "should dump/load as JSON objects" do
    packet = Nanite::Register.new('0xdeadbeef', ['/foo/bar', '/nik/qux'], 0.8)
    packet2 = JSON.parse(packet.to_json)
    packet.identity.should == packet2.identity
    packet.services.should == packet2.services
    packet.status.should == packet2.status
  end
  
  it "should dump/load as Marshalled ruby objects" do
    packet = Nanite::Register.new('0xdeadbeef', ['/foo/bar', '/nik/qux'], 0.8)
    packet2 = Marshal.load(Marshal.dump(packet))
    packet.identity.should == packet2.identity
    packet.services.should == packet2.services
    packet.status.should == packet2.status
  end
end

describe "Packet: Ping" do
  it "should dump/load as JSON objects" do
    packet = Nanite::Ping.new('0xdeadbeef', 0.8, 'from')
    packet2 = JSON.parse(packet.to_json)
    packet.identity.should == packet2.identity
    packet.status.should == packet2.status
    packet.from.should == packet2.from
  end
  
  it "should dump/load as Marshalled ruby objects" do
    packet = Nanite::Ping.new('0xdeadbeef', 0.8, 'from')
    packet2 = Marshal.load(Marshal.dump(packet))
    packet.identity.should == packet2.identity
    packet.status.should == packet2.status
    packet.from.should == packet2.from
  end
end