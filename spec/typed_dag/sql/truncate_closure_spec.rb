require 'spec_helper'

RSpec.describe TypedDag::Sql::TruncateClosure do
  describe '.sql' do
    let(:relation) { Relation.new ancestor_id: 4, descendant_id: 6, invalidate: 1 }

    def harmonize_string(string)
      string.squish.gsub('( ', '(').gsub(' )', ')')
    end

    if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
      it 'produces the correct sql for mysql' do
        expected_sql = <<-SQL
          DELETE
          FROM
            relations
          WHERE id IN (
            SELECT id
            FROM (
              SELECT COUNT(id) count, ancestor_id, descendant_id, hierarchy, invalidate
              FROM (
                SELECT ancestors.id, ancestors.ancestor_id, descendants.descendant_id,
                       ancestors.hierarchy + descendants.hierarchy AS hierarchy,
                       ancestors.invalidate + descendants.invalidate AS invalidate
                  FROM
                    relations ancestors
                  JOIN
                    relations descendants
                  ON
                    ancestors.descendant_id = 4 AND descendants.ancestor_id = 4
                  AND
                    ancestors.descendant_id = descendants.ancestor_id

                UNION ALL

                SELECT id, 4, descendant_id, hierarchy + 0, invalidate + 1
                  FROM relations
                  WHERE ancestor_id = 6

                UNION ALL

                SELECT id, ancestor_id, 6, hierarchy + 0, invalidate + 1
                  FROM relations
                  WHERE descendant_id = 4
                ) aggregation
                GROUP BY ancestor_id, descendant_id, hierarchy, invalidate) criteria
              JOIN
                (SELECT
                  id,
                  ancestor_id,
                  descendant_id,
                  hierarchy,
                  invalidate,
                  greatest(@cur_count := IF(@cur_ancestor_id = ancestor_id AND @cur_descendant_id = descendant_id AND @cur_hierarchy = hierarchy AND @cur_invalidate = invalidate,
                                         @cur_count + 1, 1),
                           least(0, @cur_ancestor_id := ancestor_id, @cur_descendant_id := descendant_id, @cur_hierarchy := hierarchy, @cur_invalidate := invalidate)) AS row_number
                FROM relations
                CROSS JOIN (SELECT @cur_count := NULL, @cur_ancestor_id := NULL, @cur_descendant_id := NULL, @cur_hierarchy := NULL, @cur_invalidate := NULL) params_initialization
                WHERE
                  ancestor_id IN (SELECT ancestor_id from relations where descendant_id = 4) OR ancestor_id = 4
                AND
                    descendant_id IN (SELECT descendant_id from relations where ancestor_id = 4)
                ORDER BY ancestor_id, descendant_id, hierarchy, invalidate) ranked
              ON ranked.ancestor_id = criteria.ancestor_id
              AND ranked.descendant_id = criteria.descendant_id
              AND ranked.hierarchy = criteria.hierarchy
              AND ranked.invalidate = criteria.invalidate
              AND count >= row_number)
        SQL

        expect(harmonize_string(described_class.sql(relation)))
          .to eql harmonize_string(expected_sql)
      end
    else
      it 'produces the correct sql for postgresql' do
        expected_sql = <<-SQL

          DELETE
          FROM
            relations
          WHERE id IN (
            SELECT id
            FROM (
              SELECT COUNT(id) count, ancestor_id, descendant_id, hierarchy, invalidate, mention
              FROM (
                SELECT ancestors.id, ancestors.ancestor_id, descendants.descendant_id,
                       ancestors.hierarchy + descendants.hierarchy AS hierarchy,
                       ancestors.invalidate + descendants.invalidate AS invalidate,
                       ancestors.mention + descendants.mention AS mention
                  FROM
                    relations ancestors
                  JOIN
                    relations descendants
                  ON
                    ancestors.descendant_id = 4 AND descendants.ancestor_id = 4
                  AND
                    ancestors.descendant_id = descendants.ancestor_id

                UNION ALL

                SELECT id, 4, descendant_id, hierarchy + 0, invalidate + 1, mention + 0
                  FROM relations
                  WHERE ancestor_id = 6

                UNION ALL

                SELECT id, ancestor_id, 6, hierarchy + 0, invalidate + 1, mention + 0
                  FROM relations
                  WHERE descendant_id = 4
                ) aggregation
                GROUP BY ancestor_id, descendant_id, hierarchy, invalidate, mention) criteria
              JOIN
                (SELECT *, ROW_NUMBER() OVER(
                  PARTITION BY ancestor_id, descendant_id, hierarchy, invalidate, mention
                )
                FROM
                relations) ranked
              ON ranked.ancestor_id = criteria.ancestor_id
              AND ranked.descendant_id = criteria.descendant_id
              AND ranked.hierarchy = criteria.hierarchy
              AND ranked.invalidate = criteria.invalidate
              AND ranked.mention = criteria.mention
              AND count >= row_number)
        SQL

        expected_sql = <<-SQL

          DELETE
          FROM
            relations
          WHERE id IN (
            SELECT id
            FROM (
              SELECT COUNT(id) count, ancestor_id, descendant_id, hierarchy, invalidate
              FROM (
                SELECT ancestors.id, ancestors.ancestor_id, descendants.descendant_id,
                       ancestors.hierarchy + descendants.hierarchy AS hierarchy,
                       ancestors.invalidate + descendants.invalidate AS invalidate
                  FROM
                    relations ancestors
                  JOIN
                    relations descendants
                  ON
                    ancestors.descendant_id = 4 AND descendants.ancestor_id = 4
                  AND
                    ancestors.descendant_id = descendants.ancestor_id

                UNION ALL

                SELECT id, 4, descendant_id, hierarchy + 0, invalidate + 1
                  FROM relations
                  WHERE ancestor_id = 6

                UNION ALL

                SELECT id, ancestor_id, 6, hierarchy + 0, invalidate + 1
                  FROM relations
                  WHERE descendant_id = 4
                ) aggregation
                GROUP BY ancestor_id, descendant_id, hierarchy, invalidate) criteria
              JOIN
                (SELECT *, ROW_NUMBER() OVER(
                  PARTITION BY ancestor_id, descendant_id, hierarchy, invalidate
                  )
                FROM
                  relations
                WHERE
                  ancestor_id IN (SELECT ancestor_id from relations where descendant_id = 4) OR ancestor_id = 4
                AND
                  descendant_id IN (SELECT descendant_id from relations where ancestor_id = 4)) ranked
              ON ranked.ancestor_id = criteria.ancestor_id
              AND ranked.descendant_id = criteria.descendant_id
              AND ranked.hierarchy = criteria.hierarchy
              AND ranked.invalidate = criteria.invalidate
              AND count >= row_number)
        SQL

        expect(harmonize_string(described_class.sql(relation)))
          .to eql harmonize_string(expected_sql)
      end
    end
  end
end
