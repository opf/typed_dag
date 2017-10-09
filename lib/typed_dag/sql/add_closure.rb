require 'typed_dag/sql/relation_access'
require 'typed_dag/sql/select_closure'

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
        #{closure_select}
      SQL
    end

    private

    def closure_select
      TypedDag::Sql::SelectClosure.sql(relation)
    end
  end
end
