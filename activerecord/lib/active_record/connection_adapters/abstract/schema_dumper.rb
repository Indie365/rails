require 'ipaddr'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # The goal of this module is to move Adapter specific column
    # definitions to the Adapter instead of having it in the schema
    # dumper itself. This code represents the normal case.
    # We can then redefine how certain data types may be handled in the schema dumper on the
    # Adapter level by over-writing this code inside the database specific adapters
    module ColumnDumper
      def column_spec(column, types)
        spec = prepare_column_options(column, types)
        spec.except(:name, :type).each{ |k, v| spec[k] = "#{k.to_s}: #{v}"}
        spec
      end

      # This can be overridden on a Adapter level basis to support other
      # extended datatypes (Example: Adding an array option in the
      # PostgreSQLAdapter)
      def prepare_column_options(column, types)
        spec = {}
        spec[:name]      = column.name.inspect
        spec[:type]      = column.type.to_s
        spec[:limit]     = column.limit.inspect if column.limit != types[column.type][:limit]
        spec[:precision] = column.precision.inspect if column.precision
        spec[:scale]     = column.scale.inspect if column.scale
        spec[:null]      = 'false' unless column.null
        spec[:default]   = default_string(column) if column.has_default?
        spec
      end

      # Lists the valid migration options
      def migration_keys
        [:name, :limit, :precision, :scale, :default, :null]
      end

      private

      def default_string(column)
        value = column.type_cast_for_database(column.default)

        if value.is_a?(::String)
          value.inspect
        else
          value
        end
      end
    end
  end
end
