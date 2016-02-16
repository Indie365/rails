require 'rails/generators/active_record'

module ActiveRecord
  module Generators # :nodoc:
    class ModelGenerator < Base # :nodoc:
      argument :attributes, :type => :array, :default => [], :banner => "field[:type][:index] field[:type][:index]"

      check_class_collision

      class_option :migration, type: :boolean
      class_option :timestamps, type: :boolean
      class_option :parent, type: :string, desc: "The parent class for the generated model"
      class_option :indexes, type: :boolean, default: true, desc: "Add indexes for references and belongs_to columns"
      class_option :primary_key_type, type: :string, desc: "The type for primary key"
      class_option :abstract, type: :boolean, default: false, desc: "Create model as abstract class"

      # creates the migration file for the model.
      def create_migration_file
        return unless options[:migration] && options[:parent].nil? && !abstract?
        attributes.each { |a| a.attr_options.delete(:index) if a.reference? && !a.has_index? } if options[:indexes] == false
        migration_template "../../migration/templates/create_table_migration.rb", "db/migrate/create_#{table_name}.rb"
      end

      def create_model_file
        template 'model.rb', File.join('app/models', class_path, "#{file_name}.rb")
      end

      def create_module_file
        return if regular_class_path.empty?
        template 'module.rb', File.join('app/models', "#{class_path.join('/')}.rb") if behavior == :invoke
      end

      def abstract?
        options[:abstract]
      end

      hook_for :test_framework

      protected

        def attributes_with_index
          attributes.select { |a| !a.reference? && a.has_index? }
        end

        # Used by the migration template to determine the parent name of the model
        def parent_class_name
          options[:parent] || determine_default_parent_class
        end

        def determine_default_parent_class
          application_record = nil

          in_root do
            application_record = if mountable_engine?
              File.exist?("app/models/#{namespaced_path}/application_record.rb")
            else
              File.exist?('app/models/application_record.rb')
            end
          end

          if application_record
            "ApplicationRecord"
          else
            "ActiveRecord::Base"
          end
        end
    end
  end
end
