require File.dirname(__FILE__) + '/spec_helper'
require 'nanite/resource'
require 'nanite/dispatcher'


def res(res)
  Nanite::Resource.new(res)
end

include Nanite

describe 'Nanite Resource Set Matching' do

  it 'should properly match top-level required resources with lower-level provided resources' do
    Dispatcher.can_provide?([res('/cluster')], [res('/cluster/rd00'), res('/node/1')]).should be_true
    Dispatcher.can_provide?([res('/node')], [res('/cluster/rd00'), res('/node/1')]).should be_true
  end

  it 'should not match a top-level required resource with a lower-level one that is not the root of a provided resource' do
    Dispatcher.can_provide?([res('/bad')], [res('/cluster/rd00')]).should be_false
    Dispatcher.can_provide?([res('/cluster')], [res('/bad/rd00')]).should be_false
  end

end