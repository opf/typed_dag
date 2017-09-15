require 'typed_dag/sql/helper'

module TypedDag::Sql::InsertClosureOfDepth
  def self.sql(configuration, depth)
    Sql.new(configuration).sql(depth)
  end

  class Sql
    def initialize(configuration)
      self.helper = ::TypedDag::Sql::Helper.new(configuration)
    end

    def sql(depth)
      <<-SQL
        INSERT INTO #{helper.table_name}
          (#{insert_list})
        SELECT
          #{select_list}
        FROM #{helper.table_name} r1
        JOIN #{helper.table_name} r2
        ON #{join_condition(depth)}
      SQL
    end

    private

    def insert_list
      [helper.from_column,
       helper.to_column,
       helper.type_select_list].join(', ')
    end

    def select_list
      <<-SQL
        r1.#{helper.from_column},
        r2.#{helper.to_column},
        #{helper.type_select_summed_columns('r1', 'r2')}
      SQL
    end

    def join_condition(depth)
      <<-SQL
        r1.#{helper.to_column} = r2.#{helper.from_column}
        AND (#{helper.sum_of_type_columns('r1.')} = #{depth})
        AND (#{helper.sum_of_type_columns('r2.')} = 1)
      SQL
    end

    attr_accessor :helper
  end
end
