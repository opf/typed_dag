module TypedDag::Edge
  module ClosureMaintenance
    extend ActiveSupport::Concern

    included do
      after_create :add_closures
      after_update :alter_closure
      after_destroy :truncate_closures

      private

      def add_closures
        return unless direct?

        self.class.connection.execute add_dag_closure_sql
      end

      def truncate_closures
        # The destroyed callback is also run for unpersisted records.
        # However, #persisted? will be false for destroyed records.
        return unless direct? && !new_record?

        self.class.connection.execute truncate_dag_closure_sql(self)
      end

      def truncate_closures_with_former_values
        former_values_relation = self.dup

        # rails 5.1 vs rails 5.0
        changes = if respond_to?(:saved_changes)
                    saved_changes.transform_values(&:first)
                  else
                    changed_attributes
                  end

        former_values_relation.attributes = changes

        self.class.connection.execute truncate_dag_closure_sql(former_values_relation)
      end

      def alter_closure
        return unless direct?

        truncate_closures_with_former_values
        add_closures
      end

      def add_dag_closure_sql
        TypedDag::Sql::AddClosure.sql(self)
      end

      def truncate_dag_closure_sql(relation)
        TypedDag::Sql::TruncateClosure.sql(relation)
      end

      def from_id_value
        send(_dag_options.from_column)
      end

      def to_id_value
        send(_dag_options.to_column)
      end
    end
  end
end
