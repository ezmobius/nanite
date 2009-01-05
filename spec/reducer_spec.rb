require File.dirname(__FILE__) + '/spec_helper'
require 'nanite'
require 'nanite/mapper'
require 'nanite/reducer'
require 'json'

describe "Nanite::Reducer" do
  it "should handle an Answer" do
    pending
    answer = Nanite::Answer.new('0xdeadbeef')
    answer.workers = {'fred' => :waiting}
    reducer = Nanite::Reducer.new
    Nanite.callbacks[answer.token] = Proc.new{|r| @r = r}
    Nanite.mapper = mock('Nanite::Mapper')
    Nanite.mapper.should_receive(:timeouts).and_return({})
    reducer.watch_for(answer)
    result = Nanite::Result.new(answer.token, 'fred', 'hello', 'fred')
    reducer.handle_result(result)
    @r['fred'].should == 'hello'
  end
end
