# frozen_string_literal: true
module ActiveRecord
  module ConnectionAdapters
    # PostgreSQL-specific extensions to column definitions in a table.
    class PostgreSQLColumn < Column #:nodoc:
      delegate :array, :oid, :fmod, to: :sql_type_metadata
      alias :array? :array

      def serial?
        return unless default_function

        table_name = @table_name || '(?<table_name>.+)'
        %r{\Anextval\('"?#{table_name}_#{name}_seq"?'::regclass\)\z} === default_function
      end
    end
  end
end
