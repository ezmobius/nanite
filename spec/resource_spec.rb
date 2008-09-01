require File.dirname(__FILE__) + '/spec_helper'
require 'nanite/resource'

include Nanite

describe 'Nanite Resource' do

  it 'should be equal if input is equal' do
    Resource.new('/').should == Resource.new('/')
    Resource.new('/foo').should == Resource.new('/foo')
    Resource.new('/foo/bar').should == Resource.new('/foo/bar')
  end

  it '/ should be >= /foo' do
    (Resource.new('/') >= Resource.new('/foo')).should be_true
  end

  it '/foo/ should be <= /' do
    (Resource.new('/foo') <= Resource.new('/')).should be_true
  end

  it '/foo should be >= /foo/bar' do
    (Resource.new('/foo') >= Resource.new('/foo/bar')).should be_true
  end

  it '/foo/bar should be <= /foo' do
    (Resource.new('/foo/bar') <= Resource.new('/foo')).should be_true
  end

  it "should be uniq" do
    [Resource.new('/foo'),Resource.new('/foo')].uniq.size.should == 1
  end

end