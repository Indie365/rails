require 'abstract_unit'

class NullResolverTest < ActiveSupport::TestCase
  def test_should_return_template_for_any_path
    resolver = ActionView::NullResolver.new()
    templates = resolver.find_all("path.erb", "arbitrary", false, {:locale => [], :formats => [:html], :handlers => []})
    assert_equal 1, templates.size, "expected one template"
    assert_equal "Template generated by Null Resolver", templates.first.source
    assert_equal "arbitrary/path.erb", templates.first.virtual_path
    assert_equal [:html],          templates.first.formats
  end
end
