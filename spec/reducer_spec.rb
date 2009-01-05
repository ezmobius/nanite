require File.dirname(__FILE__) + '/spec_helper'
require 'nanite'
require 'nanite/mapper'
require 'nanite/reducer'
require 'json'

describe "Nanite::Reducer" do
  it "should handle an Answer" do
    nanite = Nanite::Agent.new
    answer = Nanite::Answer.new(nanite, '0xdeadbeef')
    answer.workers = {'fred' => :waiting}
    reducer = Nanite::Reducer.new(nanite)
    nanite.callbacks[answer.token] = Proc.new{|r| @r = r}
    nanite.mapper = mock('Nanite::Mapper')
    nanite.mapper.should_receive(:timeouts).and_return({})
    reducer.watch_for(answer)
    result = Nanite::Result.new(answer.token, 'fred', 'hello', 'fred')
    reducer.handle_result(result)
    @r['fred'].should == 'hello'
  end
end
