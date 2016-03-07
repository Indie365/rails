# frozen_string_literal: true
module ActiveRecord
  # = Active Record Query Cache
  class QueryCache
    module ClassMethods
      # Enable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      def cache(&block)
        if ActiveRecord::Base.connected?
          connection.cache(&block)
        else
          yield
        end
      end

      # Disable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      def uncached(&block)
        if ActiveRecord::Base.connected?
          connection.uncached(&block)
        else
          yield
        end
      end
    end

    def self.install_executor_hooks(executor = ActiveSupport::Executor)
      executor.to_run do
        connection    = ActiveRecord::Base.connection
        enabled       = connection.query_cache_enabled
        connection_id = ActiveRecord::Base.connection_id
        connection.enable_query_cache!

        @restore_query_cache_settings = lambda do
          ActiveRecord::Base.connection_id = connection_id
          ActiveRecord::Base.connection.clear_query_cache
          ActiveRecord::Base.connection.disable_query_cache! unless enabled
        end
      end

      executor.to_complete do
        @restore_query_cache_settings.call if defined?(@restore_query_cache_settings)

        # FIXME: This should be skipped when env['rack.test']
        ActiveRecord::Base.clear_active_connections!
      end
    end
  end
end
