require 'spec_helper'

RSpec.describe TypedDag::Sql::TruncateClosure do
  include TypedDag::Specs::Helpers

  describe '.sql' do
    let(:relation) { Relation.new ancestor_id: 4, descendant_id: 6, invalidate: 1 }

    it 'produces the correct sql' do
      expected_sql = if mysql_db?
        <<-SQL
          UPDATE
            relations
          JOIN
            (SELECT
              ancestor_id,
              descendant_id,
              hierarchy,
              invalidate,
              SUM(count) AS count
            FROM
              (SELECT
                r1.ancestor_id,
                r2.descendant_id,
                CASE
                  WHEN r1.descendant_id = r2.ancestor_id AND (r1.hierarchy > 0 OR r2.hierarchy > 0)
                  THEN r1.hierarchy + r2.hierarchy
                  WHEN r1.descendant_id != r2.ancestor_id
                  THEN r1.hierarchy + r2.hierarchy + 0
                  ELSE 0
                  END AS hierarchy,
                CASE
                  WHEN r1.descendant_id = r2.ancestor_id AND (r1.invalidate > 0 OR r2.invalidate > 0)
                  THEN r1.invalidate + r2.invalidate
                  WHEN r1.descendant_id != r2.ancestor_id
                  THEN r1.invalidate + r2.invalidate + 1
                  ELSE 0
                  END AS invalidate,
                r1.count * r2.count AS count
              FROM
                relations r1
              JOIN
                relations r2
              ON
                (r1.descendant_id = 4 AND r2.ancestor_id = 6 AND NOT (r1.ancestor_id = 4 AND r2.descendant_id = 6))) unique_rows
            GROUP BY
              ancestor_id,
              descendant_id,
              hierarchy,
              invalidate) removed_relations
          ON relations.ancestor_id = removed_relations.ancestor_id
            AND relations.descendant_id = removed_relations.descendant_id
            AND relations.hierarchy = removed_relations.hierarchy
            AND relations.invalidate = removed_relations.invalidate
          SET
            relations.count = relations.count - removed_relations.count
        SQL
      else
        expected_sql = <<-SQL
          UPDATE
            relations
          SET
            count = relations.count - removed_relations.count
          FROM
            (SELECT
              ancestor_id,
              descendant_id,
              hierarchy,
              invalidate,
              SUM(count) AS count
            FROM
              (SELECT
                r1.ancestor_id,
                r2.descendant_id,
                CASE
                  WHEN r1.descendant_id = r2.ancestor_id AND (r1.hierarchy > 0 OR r2.hierarchy > 0)
                  THEN r1.hierarchy + r2.hierarchy
                  WHEN r1.descendant_id != r2.ancestor_id
                  THEN r1.hierarchy + r2.hierarchy + 0
                  ELSE 0
                  END AS hierarchy,
                CASE
                  WHEN r1.descendant_id = r2.ancestor_id AND (r1.invalidate > 0 OR r2.invalidate > 0)
                  THEN r1.invalidate + r2.invalidate
                  WHEN r1.descendant_id != r2.ancestor_id
                  THEN r1.invalidate + r2.invalidate + 1
                  ELSE 0
                  END AS invalidate,
                r1.count * r2.count AS count
              FROM
                relations r1
              JOIN
                relations r2
              ON
                (r1.descendant_id = 4 AND r2.ancestor_id = 6 AND NOT (r1.ancestor_id = 4 AND r2.descendant_id = 6))) unique_rows
            GROUP BY
              ancestor_id,
              descendant_id,
              hierarchy,
              invalidate) removed_relations
          WHERE relations.ancestor_id = removed_relations.ancestor_id
            AND relations.descendant_id = removed_relations.descendant_id
            AND relations.hierarchy = removed_relations.hierarchy
            AND relations.invalidate = removed_relations.invalidate
        SQL

        expect(harmonize_string(described_class.sql(relation)))
          .to eql harmonize_string(expected_sql)
      end
    end
  end
end
