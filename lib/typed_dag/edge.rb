require 'active_support/concern'
require 'typed_dag/configuration'

module TypedDag::Edge
  extend ActiveSupport::Concern

  included do
  end

  module ClassMethods
    def acts_as_dag_edge(options)
      @acts_as_dag_edge_options = TypedDag::Configuration.new(options)

      include InstanceMethods
      include Associations
    end

    def _dag_options
      @acts_as_dag_edge_options
    end
  end

  module InstanceMethods
    def _dag_options
      self.class._dag_options
    end

    def add_closures
      return unless send(_dag_options.depth_column) == 1 && send(_dag_options.type_column) == 'hierarchy'

      ancestor_id = send(_dag_options.ancestor_column)
      descendant_id = send(_dag_options.descendant_column)

      self.class.connection.execute <<-SQL
        INSERT INTO #{self.class.table_name}
          (#{_dag_options.ancestor_column},
          #{_dag_options.descendant_column},
          #{_dag_options.type_column},
          #{_dag_options.depth_column})
        SELECT
          r1.#{_dag_options.ancestor_column},
          r2.#{_dag_options.descendant_column},
          'hierarchy',
          CASE
            WHEN r1.#{_dag_options.ancestor_column} = r2.#{_dag_options.descendant_column}
            THEN r1.#{_dag_options.depth_column} + r2.#{_dag_options.depth_column}
            ELSE r1.#{_dag_options.depth_column} + r2.#{_dag_options.depth_column} + 1
            END
        FROM
          #{self.class.table_name} r1
        JOIN
          #{self.class.table_name} r2
        ON
          (r1.#{_dag_options.descendant_column} = #{ancestor_id} AND r2.#{_dag_options.ancestor_column} = #{descendant_id})
        OR
          (r1.#{_dag_options.descendant_column} = r2.#{_dag_options.ancestor_column} AND r1.#{_dag_options.descendant_column} IN (#{ancestor_id}, #{descendant_id}))
      SQL
    end

    def memorize_closures_to_destroy
      return unless send(_dag_options.depth_column) == 1 && send(_dag_options.type_column) == 'hierarchy'

      ancestor_id = send(_dag_options.ancestor_column)
      descendant_id = send(_dag_options.descendant_column)

      @closures_to_destroy = self.class.connection.select_values <<-SQL
        SELECT
          r1.id
        FROM
          #{self.class.table_name} r1
        JOIN
          #{self.class.table_name} r2
        ON
          r2.#{_dag_options.ancestor_column} = r1.#{_dag_options.ancestor_column} AND r2.#{_dag_options.descendant_column} = #{descendant_id}
        JOIN
          #{self.class.table_name} r3
        ON
          r3.#{_dag_options.descendant_column} = r1.#{_dag_options.descendant_column} AND r3.#{_dag_options.ancestor_column} = #{ancestor_id}
      SQL
    end

    def truncate_closures
      return unless @closures_to_destroy && !@closures_to_destroy.empty?

      self.class.where(id: @closures_to_destroy).delete_all

      @closures_to_destroy = nil
    end
  end

  module Associations
    extend ActiveSupport::Concern

    included do
      after_create :add_closures
      before_destroy :memorize_closures_to_destroy
      after_destroy :truncate_closures

      belongs_to :ancestor,
                 class_name: _dag_options.node_class_name,
                 foreign_key: _dag_options.ancestor_column
      belongs_to :descendant,
                 class_name: _dag_options.node_class_name,
                 foreign_key: _dag_options.descendant_column
    end
  end
end
