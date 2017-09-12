require 'typed_dag/sql/helper'

module TypedDag::Sql::RelationAccess
  extend ActiveSupport::Concern

  included do
    private

    attr_accessor :relation, :helper

    delegate :table_name,
             :ancestor_column,
             :descendant_column,
             :type_columns,
             :type_select_list,
             to: :helper

    def id_value
      relation.id
    end

    def ancestor_id_value
      relation.send(ancestor_column)
    end

    def descendant_id_value
      relation.send(descendant_column)
    end

    def type_values
      type_columns.map do |column|
        relation.send(column)
      end
    end

    def helper
      @helper ||= ::TypedDag::Sql::Helper.new(relation._dag_options)
    end
  end
end
