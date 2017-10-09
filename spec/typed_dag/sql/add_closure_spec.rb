require 'spec_helper'

RSpec.describe TypedDag::Sql::AddClosure do
  describe '.sql' do
    let(:relation) { Relation.new id: 11, ancestor_id: 4, descendant_id: 6, invalidate: 1 }

    def harmonize_string(string)
      string.squish.gsub('( ', '(').gsub(' )', ')').gsub(' , ', ', ')
    end

    it 'produces the correct sql' do
      expected_sql = <<-SQL
        INSERT INTO

          relations

          (ancestor_id,
          descendant_id,
          hierarchy, invalidate)
        SELECT
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
            END AS invalidate

        FROM
          relations r1
        JOIN
          relations r2
        ON
          (r1.descendant_id = 4 AND r2.ancestor_id = 6 AND NOT (r1.ancestor_id = 4 AND r2.descendant_id = 6))
      SQL

      expect(harmonize_string(described_class.sql(relation)))
        .to eql harmonize_string(expected_sql)
    end
  end
end
