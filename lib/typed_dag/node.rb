require 'active_support/concern'
require 'typed_dag/configuration'

module TypedDag::Node
  extend ActiveSupport::Concern

  included do
  end

  module ClassMethods
    def acts_as_dag_node(options)
      @acts_as_dag_node_options = TypedDag::Configuration.new(options)

      include InstanceMethods
      include Associations
    end

    def _dag_options
      @acts_as_dag_node_options
    end
  end

  module Associations
    extend ActiveSupport::Concern

    included do
      def self.dag_hierarchy_relations_lambda(depth = nil)
        ->(instance) {
          edges_conditions = { instance._dag_options.type_column => 'hierarchy' }

          edges_conditions[instance._dag_options.depth_column] = depth if depth

          where(instance._dag_options.edge_class_name.constantize.table_name => edges_conditions)
        }
      end

      has_many :relations_from,
               class_name: _dag_options.edge_class_name,
               foreign_key: _dag_options.ancestor_column,
               dependent: :destroy

      has_many :relations_to,
               class_name: _dag_options.edge_class_name,
               foreign_key: _dag_options.descendant_column,
               dependent: :destroy

      has_one :parent_relation,
              dag_hierarchy_relations_lambda(1),
              class_name: _dag_options.edge_class_name,
              foreign_key: _dag_options.descendant_column

      has_one :parent,
              through: :parent_relation,
              source: :ancestor

      has_many :child_relations,
               dag_hierarchy_relations_lambda(1),
               class_name: _dag_options.edge_class_name,
               foreign_key: _dag_options.ancestor_column

      has_many :children,
               through: :child_relations,
               source: :descendant

      has_many :descendant_relations,
               dag_hierarchy_relations_lambda,
               class_name: _dag_options.edge_class_name,
               foreign_key: _dag_options.ancestor_column

      has_many :descendants,
               through: :descendant_relations,
               source: :descendant

      has_many :ancestor_relations,
               dag_hierarchy_relations_lambda,
               class_name: _dag_options.edge_class_name,
               foreign_key: _dag_options.descendant_column

      has_many :ancestors,
               through: :ancestor_relations,
               source: :ancestor
    end
  end

  module InstanceMethods
    def leaf?
      !relations_from
        .where(_dag_options.type_column => 'hierarchy')
        .exists?
    end

    def child?
      !!parent_relation
    end

    def in_closure?(other_node)
      ancestor_edge(other_node)
        .or(descendant_edge(other_node))
        .exists?
    end

    def ancestor_edge(other_node)
      ancestor_relations
        .where(_dag_options.edge_table_name => { _dag_options.ancestor_column => other_node })
    end

    def descendant_edge(other_node)
      descendant_relations
        .where(_dag_options.edge_table_name => { _dag_options.descendant_column => other_node })
    end

    def _dag_options
      self.class._dag_options
    end
  end
end
