require 'typed_dag/sql/helper'

module TypedDag::Sql::GetCircular
  def self.sql(configuration, depth)
    Sql.new(configuration).sql(depth)
  end

  class Sql
    def initialize(configuration)
      self.helper = ::TypedDag::Sql::Helper.new(configuration)
    end

    def sql(depth)
      <<-SQL
        SELECT
          r1.#{helper.ancestor_column},
          r1.#{helper.descendant_column}
        FROM #{helper.table_name} r1
        JOIN #{helper.table_name} r2
        ON #{join_condition(depth)}
      SQL
    end

    private

    attr_accessor :helper

    def join_condition(depth)
      <<-SQL
        r1.#{helper.ancestor_column} = r2.#{helper.descendant_column}
        AND r1.#{helper.descendant_column} = r2.#{helper.ancestor_column}
        AND (#{helper.sum_of_type_columns('r1.')} = 1)
        AND (#{helper.sum_of_type_columns('r2.')} = #{depth})
      SQL
    end
  end
end
