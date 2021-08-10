# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class Batch # :nodoc:
        def initialize(preloaders, async: false, available_records:)
          @preloaders = preloaders.reject(&:empty?)
          @available_records = available_records.flatten.group_by(&:class)
          @async = async
        end

        def call
          branches = @preloaders.flat_map(&:branches)
          until branches.empty?
            loaders = branches.flat_map(&:runnable_loaders)

            loaders.each { |loader| loader.associate_records_from_unscoped(@available_records[loader.klass]) }

            already_loaded = loaders.select(&:data_available?)
            if already_loaded.any?
              already_loaded.each(&:run)
            elsif loaders.any?
              future_tables = branches.flat_map do |branch|
                branch.future_classes - branch.runnable_loaders.map(&:klass)
              end.map(&:table_name).uniq

              target_loaders = loaders.reject { |l| future_tables.include?(l.table_name)  }
              target_loaders = loaders if target_loaders.empty?

              group_and_load_similar(target_loaders)
              target_loaders.each(&:run)
            end

            finished, in_progress = branches.partition(&:done?)

            branches = in_progress + finished.flat_map(&:children)
          end
        end

        private
          attr_reader :loaders

          def group_and_load_similar(loaders)
            loaders.grep_v(ThroughAssociation).group_by(&:loader_query).each_pair do |query, similar_loaders|
              result = query.load_records_in_batch(similar_loaders)
              result.load_async if @async
            end
          end
      end
    end
  end
end
