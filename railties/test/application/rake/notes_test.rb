require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class RakeNotesTest < ActiveSupport::TestCase
      def setup 
        build_app
        require "rails/all"
      end
    
      def teardown
        teardown_app
      end

      test 'notes' do

        app_file "app/views/home/index.html.erb", "<% # TODO: note in erb %>"
        app_file "app/views/home/index.html.haml", "-# TODO: note in haml"
        app_file "app/views/home/index.html.slim", "/ TODO: note in slim"
        app_file "app/controllers/application_controller.rb", 1000.times.map { "" }.join("\n") << "# TODO: note in ruby"
        app_file "test/test_helper.rb", "# TODO: note in test"
        app_file "db/seeds.rb", "# TODO: note in seeds"
        app_file "spec/spec_helper.rb", "# TODO: note in spec"

        boot_rails
        require 'rake'
        require 'rdoc/task'
        require 'rake/testtask'

        Rails.application.load_tasks
   
        Dir.chdir(app_path) do
          output = `bundle exec rake notes`
          lines = output.scan(/\[([0-9\s]+)\]/).flatten
        
          assert_match /note in erb/, output
          assert_match /note in haml/, output
          assert_match /note in slim/, output
          assert_match /note in ruby/, output
          assert_match /note in test/, output
          assert_match /note in seeds/, output
          assert_match /note in spec/,  output

          assert_equal 7, lines.size
          assert_equal 4, lines[0].size
          assert_equal 4, lines[1].size
          assert_equal 4, lines[2].size
          assert_equal 4, lines[3].size
          assert_equal 4, lines[4].size
          assert_equal 4, lines[5].size
          assert_equal 4, lines[6].size
        end
      
      end
    
      private
      def boot_rails
        super
        require "#{app_path}/config/environment"
      end
    end
  end
end
