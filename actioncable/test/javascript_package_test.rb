# frozen_string_literal: true

require "test_helper"

class JavascriptPackageTest < ActiveSupport::TestCase
  def test_compiled_code_is_in_sync_with_source_code
    compiled_files = %w[
      app/assets/javascripts/actioncable.js
      app/assets/javascripts/actioncable.esm.js
      app/assets/javascripts/action_cable.js
    ].map do |file|
      Pathname(file).expand_path("#{__dir__}/..")
    end

    logs = %w[1 t true].include?(ENV["LOG"]) ? "" : " > /dev/null 2>&1"

    assert_no_changes -> { compiled_files.map(&:read) } do
      system "yarn build#{logs}", exception: true
    end
  end
end
