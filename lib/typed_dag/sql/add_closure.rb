require 'typed_dag/sql/relation_access'

module TypedDag::Sql::AddClosure
  def self.sql(relation)
    Sql.new(relation).sql
  end

  class Sql
    include TypedDag::Sql::RelationAccess

    def initialize(relation)
      self.relation = relation
    end

    def sql
      <<-SQL
        INSERT INTO #{table_name}
          (#{from_column},
          #{to_column},
          #{type_select_list})
        SELECT
          r1.#{from_column},
          r2.#{to_column},
          #{depth_sum_case}
        FROM
          #{table_name} r1
        JOIN
          #{table_name} r2
        ON
          (#{relations_join_combines_paths_condition})
        OR
          (#{relations_join_extends_paths_condition})
      SQL
    end

    private

    def depth_sum_case
      type_columns.map do |column|
        <<-SQL
          CASE
            WHEN r1.#{to_column} = r2.#{from_column} AND (r1.#{column} > 0 OR r2.#{column} > 0)
            THEN r1.#{column} + r2.#{column}
            WHEN r1.#{to_column} != r2.#{from_column}
            THEN r1.#{column} + r2.#{column} + #{relation.send(column)}
            ELSE 0
            END
        SQL
      end.join(', ')
    end

    def relations_join_combines_paths_condition
      <<-SQL
        r1.#{to_column} = #{from_id_value} AND r2.#{from_column} = #{to_id_value}
      SQL
    end

    def relations_join_extends_paths_condition
      <<-SQL
        r1.#{to_column} = r2.#{from_column} AND (r1.id = #{id_value} OR r2.id = #{id_value})
      SQL
    end
  end
end
