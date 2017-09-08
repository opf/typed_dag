require 'typed_dag/sql/relation_access'

module TypedDag::Sql::TruncateClosure
  def self.sql(deleted_relation)
    Sql.new(deleted_relation).sql
  end

  class Sql
    include TypedDag::Sql::RelationAccess

    def initialize(relation)
      self.relation = relation
    end

    def sql
      <<-SQL
        DELETE FROM
          #{table_name}
        WHERE id IN
          (SELECT id
          FROM (
            SELECT COUNT(id) count, #{ancestor_column}, #{descendant_column}, #{type_select_list}
            FROM (

               #{select_relations_joined_by_descendant_and_ancestor}

             UNION ALL

                #{select_relations_starting_from_descendant}

             UNION ALL

                #{select_relations_ending_in_ancestor}

             ) aggregation
             GROUP BY #{ancestor_column}, #{descendant_column}, #{type_select_list}) criteria

          JOIN
            (#{rank_similar_relations}) ranked
          ON
            #{ranked_critieria_join_condition})
      SQL
    end

    private

    attr_accessor :relation

    def select_relations_joined_by_descendant_and_ancestor
      <<-SQL
        SELECT ancestors.id, ancestors.#{ancestor_column}, descendants.#{descendant_column}, #{type_sums_select_list}
          FROM
            relations ancestors
          JOIN
            relations descendants
          ON
              ancestors.#{descendant_column} = #{ancestor_id_value} AND descendants.#{ancestor_column} = #{ancestor_id_value}
            AND
              ancestors.#{descendant_column} = descendants.#{ancestor_column}
      SQL
    end

    def select_relations_starting_from_descendant
      <<-SQL
        SELECT id, #{ancestor_id_value}, #{descendant_column}, #{type_sum_value_select_list}
          FROM relations
          WHERE #{ancestor_column} = #{descendant_id_value}
      SQL
    end

    def select_relations_ending_in_ancestor
      <<-SQL
        SELECT id, #{ancestor_column}, #{descendant_id_value}, #{type_sum_value_select_list}
             FROM relations
             WHERE #{descendant_column} = #{ancestor_id_value}
      SQL
    end

    def rank_similar_relations
      if mysql_db?
        rank_similar_relations_mysql
      else
        rank_similar_relations_postgresql
      end
    end

    def ranked_critieria_join_condition
      <<-SQL
        ranked.#{ancestor_column} = criteria.#{ancestor_column}
        AND ranked.#{descendant_column} = criteria.#{descendant_column}
        AND #{types_equality_condition}
        AND count >= row_number
      SQL
    end

    def type_column_values_pairs
      type_columns.map do |column|
        [column, relation.send(column)]
      end
    end

    def types_equality_condition
      type_columns.map do |column|
        "ranked.#{column} = criteria.#{column}"
      end.join(' AND ')
    end

    def type_sum_value_select_list
      type_column_values_pairs.map do |column, value|
        "#{column} + #{value}"
      end.join(', ')
    end

    def type_sums_select_list
      type_columns.map do |column|
        "ancestors.#{column} + descendants.#{column} AS #{column}"
      end.join(', ')
    end

    def mysql_db?
      ActiveRecord::Base.connection.adapter_name == 'Mysql2'
    end

    def rank_similar_relations_mysql
      <<-SQL
        SELECT
          id,
          #{ancestor_column},
          #{descendant_column},
          #{type_select_list},
          greatest(@cur_count := IF(#{compare_mysql_variables},
                                 @cur_count + 1, 1),
                   least(0, #{assign_mysql_variables})) AS row_number
        FROM
          relations

        CROSS JOIN (SELECT #{initialize_mysql_variables}) params_initialization

        WHERE
          #{only_relations_in_closure_condition}

        ORDER BY #{ancestor_column}, #{descendant_column}, #{type_select_list}
      SQL
    end

    def rank_similar_relations_postgresql
      <<-SQL
        SELECT *, ROW_NUMBER() OVER(
          PARTITION BY #{ancestor_column}, #{descendant_column}, #{type_select_list}
        )
        FROM
          relations
        WHERE
          #{only_relations_in_closure_condition}
      SQL
    end

    def only_relations_in_closure_condition
      <<-SQL
        #{ancestor_column} IN (SELECT #{ancestor_column} from relations where #{descendant_column} = #{ancestor_id_value}) OR #{ancestor_column} = #{ancestor_id_value}
      AND
        #{descendant_column} IN (SELECT #{descendant_column} from relations where #{ancestor_column} = #{ancestor_id_value})
      SQL
    end

    def initialize_mysql_variables
      variable_string = "@cur_count := NULL,
                         @cur_#{ancestor_column} := NULL,
                         @cur_#{descendant_column} := NULL"

      type_columns.each do |column|
        variable_string += ", @cur_#{column} := NULL"
      end

      variable_string
    end

    def assign_mysql_variables
      variable_string = "@cur_#{ancestor_column} := #{ancestor_column},
                         @cur_#{descendant_column} := #{descendant_column}"

      type_columns.each do |column|
        variable_string += ", @cur_#{column} := #{column}"
      end

      variable_string
    end

    def compare_mysql_variables
      variable_string = "@cur_#{ancestor_column} = #{ancestor_column} AND
                         @cur_#{descendant_column} = #{descendant_column}"

      type_columns.each do |column|
        variable_string += " AND @cur_#{column} = #{column}"
      end

      variable_string
    end
  end
end
