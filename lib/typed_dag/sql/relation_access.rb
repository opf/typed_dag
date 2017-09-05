module TypedDag::Sql::RelationAccess
  extend ActiveSupport::Concern

  included do
    private

    attr_accessor :relation

    def table_name
      relation.class.table_name
    end

    def ancestor_column
      relation._dag_options.ancestor_column
    end

    def descendant_column
      relation._dag_options.descendant_column
    end

    def type_columns
      relation._dag_options.type_columns
    end

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

    def type_select_list
      type_columns.join(', ')
    end
  end
end
