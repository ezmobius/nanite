require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::CertificateCache do

  before(:each) do
    @cache = Nanite::CertificateCache.new(2)
  end

  it 'should allow storing and retrieving objects' do
    @cache['some_id'].should be_nil
    @cache['some_id'] = 'some_value'
    @cache['some_id'].should == 'some_value'
  end

  it 'should not store more than required' do
    @cache[1] = 'oldest'
    @cache[2] = 'older'
    @cache[1].should == 'oldest'
    @cache[2].should == 'older'
  
    @cache[3] = 'new'
    @cache[3].should == 'new'

    @cache[1].should be_nil
    @cache[2].should == 'older'
  end

  it 'should use LRU to remove entries' do
    @cache[1] = 'oldest'
    @cache[2] = 'older'
    @cache[1].should == 'oldest'
    @cache[2].should == 'older'
  
    @cache[1] = 'new'
    @cache[3] = 'newer'
    @cache[1].should == 'new'
    @cache[3].should == 'newer'

    @cache[2].should be_nil
  end

  it 'should store items returned by block' do
    @cache[1].should be_nil
    item = @cache.get(1) { 'item' }
    item.should == 'item'
    @cache[1].should == 'item'
  end

end