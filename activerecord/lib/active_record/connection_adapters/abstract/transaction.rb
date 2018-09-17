# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class TransactionState
      def initialize(state = nil)
        @state = state
        @children = nil
      end

      def add_child(state)
        @children ||= []
        @children << state
      end

      def finalized?
        @state
      end

      def committed?
        @state == :committed || @state == :fully_committed
      end

      def fully_committed?
        @state == :fully_committed
      end

      def rolledback?
        @state == :rolledback || @state == :fully_rolledback
      end

      def fully_rolledback?
        @state == :fully_rolledback
      end

      def fully_completed?
        completed?
      end

      def completed?
        committed? || rolledback?
      end

      def rollback!
        @children&.each { |c| c.rollback! }
        @state = :rolledback
      end

      def full_rollback!
        @children&.each { |c| c.rollback! }
        @state = :fully_rolledback
      end

      def commit!
        @state = :committed
      end

      def full_commit!
        @state = :fully_committed
      end

      def nullify!
        @state = nil
      end
    end

    class NullTransaction #:nodoc:
      def initialize; end
      def state; end
      def closed?; true; end
      def open?; false; end
      def joinable?; false; end
      def add_record(record); end
    end

    class Transaction #:nodoc:
      attr_reader :connection, :state, :records, :savepoint_name, :isolation_level

      def initialize(connection, isolation: nil, joinable: true, run_commit_callbacks: false)
        @connection = connection
        @state = TransactionState.new
        @records = nil
        @isolation_level = isolation
        @materialized = false
        @joinable = joinable
        @run_commit_callbacks = run_commit_callbacks
      end

      def add_record(record)
        @records ||= []
        @records << record
      end

      def materialize!
        @materialized = true
      end

      def materialized?
        @materialized
      end

      def rollback_records
        return unless records
        ite = records.uniq(&:object_id)
        already_run_callbacks = {}
        while record = ite.shift
          trigger_callbacks = record.trigger_transactional_callbacks?
          should_run_callbacks = !already_run_callbacks[record] && trigger_callbacks
          already_run_callbacks[record] ||= trigger_callbacks
          record.rolledback!(force_restore_state: full_rollback?, should_run_callbacks: should_run_callbacks)
        end
      ensure
        ite&.each do |i|
          i.rolledback!(force_restore_state: full_rollback?, should_run_callbacks: false)
        end
      end

      def before_commit_records
        return unless records && @run_commit_callbacks

        records.uniq.sort_by(&DeadlockPreventionOrder).each(&:before_committed!)
      end

      def commit_records
        return unless records
        ite = records.uniq(&:object_id)
        already_run_callbacks = {}
        while record = ite.shift
          if @run_commit_callbacks
            trigger_callbacks = record.trigger_transactional_callbacks?
            should_run_callbacks = !already_run_callbacks[record] && trigger_callbacks
            already_run_callbacks[record] ||= trigger_callbacks
            record.committed!(should_run_callbacks: should_run_callbacks)
          else
            # if not running callbacks, only adds the record to the parent transaction
            connection.add_transaction_record(record)
          end
        end
      ensure
        ite&.each { |i| i.committed!(should_run_callbacks: false) }
      end

      def full_rollback?; true; end
      def joinable?; @joinable; end
      def closed?; false; end
      def open?; !closed?; end
    end

    class SavepointTransaction < Transaction
      def initialize(connection, savepoint_name, parent_transaction, **options)
        super(connection, **options)

        parent_transaction.state.add_child(@state)

        if isolation_level
          raise ActiveRecord::TransactionIsolationError, "cannot set transaction isolation in a nested transaction"
        end

        @savepoint_name = savepoint_name
      end

      def materialize!
        connection.create_savepoint(savepoint_name)
        super
      end

      def rollback
        connection.rollback_to_savepoint(savepoint_name) if materialized?
        @state.rollback!
      end

      def commit
        connection.release_savepoint(savepoint_name) if materialized?
        @state.commit!
      end

      def full_rollback?; false; end
    end

    class RealTransaction < Transaction
      def materialize!
        if isolation_level
          connection.begin_isolated_db_transaction(isolation_level)
        else
          connection.begin_db_transaction
        end

        super
      end

      def rollback
        connection.rollback_db_transaction if materialized?
        @state.full_rollback!
      end

      def commit
        connection.commit_db_transaction if materialized?
        @state.full_commit!
      end
    end

    class TransactionManager #:nodoc:
      def initialize(connection)
        @stack = []
        @connection = connection
        @has_unmaterialized_transactions = false
        @materializing_transactions = false
        @lazy_transactions_enabled = true
      end

      def begin_transaction(isolation: nil, joinable: true, _lazy: true)
        @connection.lock.synchronize do
          run_commit_callbacks = !current_transaction.joinable?
          transaction =
            if @stack.empty?
              RealTransaction.new(
                @connection,
                isolation: isolation,
                joinable: joinable,
                run_commit_callbacks: run_commit_callbacks
              )
            else
              SavepointTransaction.new(
                @connection,
                "active_record_#{@stack.size}",
                @stack.last,
                isolation: isolation,
                joinable: joinable,
                run_commit_callbacks: run_commit_callbacks
              )
            end

          if @connection.supports_lazy_transactions? && lazy_transactions_enabled? && _lazy
            @has_unmaterialized_transactions = true
          else
            transaction.materialize!
          end
          @stack.push(transaction)
          transaction
        end
      end

      def disable_lazy_transactions!
        materialize_transactions
        @lazy_transactions_enabled = false
      end

      def enable_lazy_transactions!
        @lazy_transactions_enabled = true
      end

      def lazy_transactions_enabled?
        @lazy_transactions_enabled
      end

      def materialize_transactions
        return if @materializing_transactions
        return unless @has_unmaterialized_transactions

        @connection.lock.synchronize do
          begin
            @materializing_transactions = true
            @stack.each { |t| t.materialize! unless t.materialized? }
          ensure
            @materializing_transactions = false
          end
          @has_unmaterialized_transactions = false
        end
      end

      def commit_transaction
        @connection.lock.synchronize do
          transaction = @stack.last

          begin
            transaction.before_commit_records
          ensure
            @stack.pop
          end

          transaction.commit
          transaction.commit_records
        end
      end

      def rollback_transaction(transaction = nil)
        @connection.lock.synchronize do
          transaction ||= @stack.pop
          transaction.rollback
          transaction.rollback_records
        end
      end

      def within_new_transaction(isolation: nil, joinable: true)
        @connection.lock.synchronize do
          transaction = begin_transaction(isolation: isolation, joinable: joinable)
          yield
        rescue Exception => error
          if transaction
            rollback_transaction
            after_failure_actions(transaction, error)
          end
          raise
        ensure
          if !error && transaction
            if Thread.current.status == "aborting"
              rollback_transaction
            else
              begin
                commit_transaction
              rescue Exception
                rollback_transaction(transaction) unless transaction.state.completed?
                raise
              end
            end
          end
        end
      end

      def open_transactions
        @stack.size
      end

      def current_transaction
        @stack.last || NULL_TRANSACTION
      end

      private
        NULL_TRANSACTION = NullTransaction.new

        # Deallocate invalidated prepared statements outside of the transaction
        def after_failure_actions(transaction, error)
          return unless transaction.is_a?(RealTransaction)
          return unless error.is_a?(ActiveRecord::PreparedStatementCacheExpired)
          @connection.clear_cache!
        end
    end

    class DeadlockPreventionOrder
      include Comparable

      def self.to_proc
        method(:new).to_proc
      end

      def self.association_depth(model, stack: [])
        @association_depth ||= {}
        @association_depth.fetch(model.name) do |key|
          stack << model
          depths = model.reflect_on_all_associations(:belongs_to).lazy
            .select { |belonging| belonging.options[:touch] }
            .map { |belonging|
              if belonging.polymorphic?
                1
              elsif stack.include?(belonging.klass) || belonging.table_name == model.table_name
                0
              else
                association_depth(belonging.klass, stack: stack) + 1
              end
            }

          @association_depth[key] = depths.max || 0
        end
      end

      delegate :association_depth, to: :class

      attr_reader :object

      def initialize(record)
        @object = record
      end

      def <=>(other)
        by_depth(other) || by_table(other) || by_id(other) || 0
      end

      private
        def by_depth(other)
          (association_depth(other.object.class) <=> association_depth(object.class)).nonzero?
        end

        def by_table(other)
          (object.class.table_name <=> other.object.class.table_name).nonzero?
        end

        def by_id(other)
          (object.id <=> other.object.id)&.nonzero?
        end
    end
  end
end
