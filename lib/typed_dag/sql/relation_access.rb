require 'typed_dag/sql/helper'

module TypedDag::Sql::RelationAccess
  extend ActiveSupport::Concern

  included do
    private

    attr_accessor :relation, :helper

    delegate :table_name,
             :from_column,
             :to_column,
             :count_column,
             :type_columns,
             :type_select_list,
             to: :helper

    def id_value
      wrapped_value('id')
    end

    def from_id_value
      wrapped_value('from_id')
    end

    def to_id_value
      wrapped_value('to_id')
    end

    def wrapped_value(column)
      uuid?(column) ? "'#{relation.send(column)}'" : relation.send(column)
    end

    def uuid?(column)
      relation.class.columns_hash[column].type == :uuid
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
