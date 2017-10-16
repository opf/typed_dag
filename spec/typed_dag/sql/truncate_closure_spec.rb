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
            deletion_table
          FROM
            relations deletion_table
          INNER JOIN
            (SELECT id
            FROM (
              SELECT COUNT(*) count, ancestor_id, descendant_id, hierarchy, invalidate
              FROM (
                SELECT
                  r1.ancestor_id,
                  r2.descendant_id,
                  CASE
                    WHEN r1.descendant_id = r2.ancestor_id AND (r1.hierarchy > 0 OR r2.hierarchy > 0)
                    THEN r1.hierarchy + r2.hierarchy
                    WHEN r1.descendant_id != r2.ancestor_id
                    THEN r1.hierarchy + r2.hierarchy + 0
                    ELSE 0
                    END AS hierarchy ,
                  CASE
                    WHEN r1.descendant_id = r2.ancestor_id AND (r1.invalidate > 0 OR r2.invalidate > 0)
                    THEN r1.invalidate + r2.invalidate
                    WHEN r1.descendant_id != r2.ancestor_id
                    THEN r1.invalidate + r2.invalidate + 1
                    ELSE 0
                    END AS invalidate

                FROM
                  relations r1
                JOIN
                  relations r2
                ON
                  (r1.descendant_id = 4 AND r2.ancestor_id = 6 AND NOT (r1.ancestor_id = 4 AND r2.descendant_id = 6))
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
                  ancestor_id IN (SELECT ancestor_id FROM relations WHERE descendant_id = 4) OR ancestor_id = 4
                AND
                    descendant_id IN (SELECT descendant_id FROM relations WHERE ancestor_id = 4)
                ORDER BY ancestor_id, descendant_id, hierarchy, invalidate) ranked
              ON ranked.ancestor_id = criteria.ancestor_id
              AND ranked.descendant_id = criteria.descendant_id
              AND ranked.hierarchy = criteria.hierarchy
              AND ranked.invalidate = criteria.invalidate
              AND count >= row_number) selection_table
            ON
              deletion_table.id = selection_table.id
        SQL

        expect(harmonize_string(described_class.sql(relation)))
          .to eql harmonize_string(expected_sql)
      end
    else
      it 'produces the correct sql for postgresql' do
        expected_sql = <<-SQL

          DELETE
          FROM
            relations deletion_table
          USING
            (SELECT id
            FROM (
              SELECT COUNT(*) count, ancestor_id, descendant_id, hierarchy, invalidate
              FROM (
                SELECT
                  r1.ancestor_id,
                  r2.descendant_id,
                  CASE
                    WHEN r1.descendant_id = r2.ancestor_id AND (r1.hierarchy > 0 OR r2.hierarchy > 0)
                    THEN r1.hierarchy + r2.hierarchy
                    WHEN r1.descendant_id != r2.ancestor_id
                    THEN r1.hierarchy + r2.hierarchy + 0
                    ELSE 0
                    END AS hierarchy ,
                  CASE
                    WHEN r1.descendant_id = r2.ancestor_id AND (r1.invalidate > 0 OR r2.invalidate > 0)
                    THEN r1.invalidate + r2.invalidate
                    WHEN r1.descendant_id != r2.ancestor_id
                    THEN r1.invalidate + r2.invalidate + 1
                    ELSE 0
                    END AS invalidate

                FROM
                  relations r1
                JOIN
                  relations r2
                ON
                  (r1.descendant_id = 4 AND r2.ancestor_id = 6 AND NOT (r1.ancestor_id = 4 AND r2.descendant_id = 6))
                ) aggregation
                GROUP BY ancestor_id, descendant_id, hierarchy, invalidate) criteria
              JOIN
                (SELECT *, ROW_NUMBER() OVER(
                  PARTITION BY ancestor_id, descendant_id, hierarchy, invalidate
                  )
                FROM
                  relations
                WHERE
                  ancestor_id IN (SELECT ancestor_id FROM relations WHERE descendant_id = 4) OR ancestor_id = 4
                AND
                  descendant_id IN (SELECT descendant_id FROM relations WHERE ancestor_id = 4)) ranked
              ON ranked.ancestor_id = criteria.ancestor_id
              AND ranked.descendant_id = criteria.descendant_id
              AND ranked.hierarchy = criteria.hierarchy
              AND ranked.invalidate = criteria.invalidate
              AND count >= row_number) selection_table
            WHERE
              deletion_table.id = selection_table.id
        SQL

        expect(harmonize_string(described_class.sql(relation)))
          .to eql harmonize_string(expected_sql)
      end
    end
  end
end
