require 'minitest/autorun'
require 'rubygems'
require 'bundler/setup'
require 'pry'
require 'mocha/mini_test'


require File.join(__dir__, '..', '..', 'app', 'models', 'base')

ENV['environment'] = 'test'

describe Base do
  describe "quote" do
    before do
      @base = Base.new
    end
    it "returns quoted string" do
      assert_equal("'foo'", @base.quote('foo'))
    end
    it "handles numbers" do
      assert_equal(1, @base.quote(1))
    end
    it "returns 'null' for nil" do
      assert_equal('null', @base.quote(nil))
    end
    it "escapes single quotes in string" do
      assert_equal("'f''oo'", @base.quote("f'oo"))
    end
    it "is accessibe as class and instance util" do
      assert_equal(Base.quote("foo"), @base.quote("foo"))
    end
  end

end
