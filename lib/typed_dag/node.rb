require 'active_support/concern'
require 'typed_dag/configuration'
require 'typed_dag/rebuild_dag'

module TypedDag::Node
  extend ActiveSupport::Concern

  included do
    include InstanceMethods
    include Associations
    include ::TypedDag::RebuildDag

    _dag_options.types.each do |key, _|
      define_singleton_method :"#{key}_leaves" do
        where.not(id: _dag_options.edge_class.select(_dag_options.from_column)
                                  .where(key => 1))
      end
    end
  end

  class_methods do
    def _dag_options
      TypedDag::Configuration[self]
    end
  end

  module Associations
    extend ActiveSupport::Concern

    included do
      def self.dag_relations_association_lambda(column, depth = 0)
        -> {
          if depth != 0
            with_type_columns(column => depth)
          else
            with_type_columns_not(column => depth)
          end
        }
      end
      private_class_method :dag_relations_association_lambda

      has_many :relations_from,
               class_name: _dag_options.edge_class_name,
               foreign_key: _dag_options.from_column,
               dependent: :destroy

      has_many :relations_to,
               class_name: _dag_options.edge_class_name,
               foreign_key: _dag_options.to_column,
               dependent: :destroy

      _dag_options.types.each do |key, config|
        if config[:from].is_a?(Hash) && config[:from][:limit] == 1
          has_one :"#{config[:from][:name]}_relation",
                  dag_relations_association_lambda(key, 1),
                  class_name: _dag_options.edge_class_name,
                  foreign_key: _dag_options.to_column

          has_one config[:from][:name],
                  through: :"#{config[:from][:name]}_relation",
                  source: :from
        else
          has_many :"#{config[:from]}_relations",
                   dag_relations_association_lambda(key, 1),
                   class_name: _dag_options.edge_class_name,
                   foreign_key: _dag_options.to_column

          has_many config[:from],
                   through: :"#{config[:from]}_relations",
                   source: :from,
                   dependent: :destroy
        end

        has_many :"#{config[:to]}_relations",
                 dag_relations_association_lambda(key, 1),
                 class_name: _dag_options.edge_class_name,
                 foreign_key: _dag_options.from_column

        has_many config[:to],
                 through: :"#{config[:to]}_relations",
                 source: :to

        has_many :"#{config[:all_to]}_relations",
                 dag_relations_association_lambda(key),
                 class_name: _dag_options.edge_class_name,
                 foreign_key: _dag_options.from_column

        has_many config[:all_to],
                 -> { distinct },
                 through: :"#{config[:all_to]}_relations",
                 source: :to

        has_many :"#{config[:all_from]}_relations",
                 dag_relations_association_lambda(key),
                 class_name: _dag_options.edge_class_name,
                 foreign_key: _dag_options.to_column

        has_many config[:all_from],
                 -> { distinct },
                 through: :"#{config[:all_from]}_relations",
                 source: :from

        define_method :"#{config[:all_to]}_of_depth" do |depth|
          send(config[:all_to])
            .where(_dag_options.edge_table_name => { key => depth })
        end

        define_method :"#{config[:all_from]}_of_depth" do |depth|
          send(config[:all_from])
            .where(_dag_options.edge_table_name => { key => depth })
        end

        define_method :"self_and_#{config[:all_from]}" do
          froms_scope = self.class.where(id: send(config[:all_from]))
          self_scope = self.class.where(id: id)

          froms_scope.or(self_scope)
        end

        define_method :"self_and_#{config[:all_to]}" do
          to_scope = self.class.where(id: send(config[:all_to]))
          self_scope = self.class.where(id: id)

          to_scope.or(self_scope)
        end

        define_method :"#{key}_leaves" do
          send(config[:all_to])
            .where(id: self.class.send("#{key}_leaves"))
        end

        define_method :"#{key}_leaf?" do
          send(:"#{config[:to]}_relations").empty?
        end

        define_method :"#{key}_root?" do
          if config[:from].is_a?(Hash) && config[:from][:limit] == 1
            send(:"#{config[:from][:name]}_relation").nil?
          else
            send(:"#{config[:from]}_relations").empty?
          end
        end
      end
    end
  end

  module InstanceMethods
    def child?
      !!parent_relation
    end

    def in_closure?(other_node)
      from_edge(other_node)
        .or(to_edge(other_node))
        .exists?
    end

    def from_edge(other_node)
      ancestors_relations
        .where(_dag_options.edge_table_name => { _dag_options.from_column => other_node })
    end

    def to_edge(other_node)
      descendants_relations
        .where(_dag_options.edge_table_name => { _dag_options.to_column => other_node })
    end

    def _dag_options
      self.class._dag_options
    end
  end
end
