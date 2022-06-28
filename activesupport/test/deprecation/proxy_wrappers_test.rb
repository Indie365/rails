# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/deprecation"

class ProxyWrappersTest < ActiveSupport::TestCase
  Waffles     = false
  NewWaffles  = :hamburgers

  module WaffleModule
    def waffle?
      true
    end
  end

  def test_deprecated_object_proxy_doesnt_wrap_falsy_objects
    proxy = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(nil, "message")
    assert_not proxy
  end

  def test_deprecated_instance_variable_proxy_doesnt_wrap_falsy_objects
    proxy = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(nil, :waffles)
    assert_not proxy
  end

  def test_deprecated_constant_proxy_doesnt_wrap_falsy_objects
    proxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new(Waffles, NewWaffles)
    assert_not proxy
  end

  def test_including_proxy_module
    proxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("OldWaffleModule", WaffleModule.name)
    klass = Class.new
    assert_deprecated do
      klass.include proxy
    end
    assert klass.new.waffle?
  end

  def test_prepending_proxy_module
    proxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("OldWaffleModule", WaffleModule.name)
    klass = Class.new do
      def waffle?
        false
      end
    end
    assert_deprecated do
      klass.prepend proxy
    end
    assert klass.new.waffle?
  end

  def test_extending_proxy_module
    proxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("OldWaffleModule", WaffleModule.name)
    obj = Object.new
    assert_deprecated do
      obj.extend proxy
    end
    assert obj.waffle?
  end
end
