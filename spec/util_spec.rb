require File.dirname(__FILE__) + '/spec_helper'
require 'nanite/util'

describe String do

  describe ".snake_case" do

    it "should downcase single word" do
      ["FOO", "Foo", "foo"].each do |w|
        w.snake_case.should == "foo"
      end
    end

    it "should not separate numbers from end of word" do
      ["Foo1234", "foo1234"].each do |w|
        w.snake_case.should == "foo1234"
      end
    end

    it "should separate numbers from word it starts with uppercase letter" do
      "1234Foo".snake_case.should == "1234_foo"
    end

    it "should not separate numbers from word starts with lowercase letter" do
      "1234foo".snake_case.should == "1234foo"
    end

    it "should downcase camel-cased words and connect with underscore" do
      ["FooBar", "fooBar"].each do |w|
        w.snake_case.should == "foo_bar"
      end
    end

    it "should start new word with uppercase letter before lower case letter" do
      ["FooBARBaz", "fooBARBaz"].each do |w|
        w.snake_case.should == "foo_bar_baz"
      end
    end

  end

  describe ".to_const_path" do

    it "should snake-case the string" do
      str = "hello"
      str.should_receive(:snake_case).and_return("snake-cased hello")
      str.to_const_path
    end

    it "should leave (snake-cased) string without '::' unchanged" do
      "hello".to_const_path.should == "hello"
    end

    it "should replace single '::' with '/'" do
      "hello::world".to_const_path.should == "hello/world"
    end
    
    it "should replace multiple '::' with '/'" do
      "hello::nanite::world".to_const_path.should == "hello/nanite/world"
    end

  end

end # String
