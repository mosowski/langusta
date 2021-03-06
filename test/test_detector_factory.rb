# -*- coding: utf-8 -*-
require 'test/helper'

class DetectorFactoryTest < Test::Unit::TestCase
  def test_add_profile
    profile = LangProfile.new('sample')
    factory = DetectorFactory.new

    factory.add_profile(profile)
    
    detector = factory.create(0.123)
    assert_equal(0.123, detector.alpha)
  end

  def test_exceptions
    profile = LangProfile.new('sample')
    factory = DetectorFactory.new

    assert_raises(NoProfilesLoadedError) do
      factory.create()
    end

    factory.add_profile(profile)

    assert_raises(DuplicateProfilesError) do
      factory.add_profile(profile)
    end
  end

  def test_inspect
    profile = LangProfile.new('sample')
    factory = DetectorFactory.new

    factory.add_profile(profile)

    assert_match(Regexp.new(factory.object_ptr), factory.inspect)
    assert_match(/1 profile\(s\)/, factory.inspect)
    assert_match(Regexp.new(factory.class.name), factory.inspect)
  end
end
