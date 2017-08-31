require 'active_support/concern'

module TypedDag::Edge
  extend ActiveSupport::Concern

  included do
    belongs_to :from, class_name: 'WorkPackage', foreign_key: 'from_id'
    belongs_to :to, class_name: 'WorkPackage', foreign_key: 'to_id'

    after_create :add_closures
    before_destroy :memorize_closures_to_destroy
    after_destroy :truncate_closures

    def add_closures
      return unless depth == 1 && relation_type == 'hierarchy'

      self.class.connection.execute <<-SQL
        INSERT INTO relations
          (from_id, to_id, relation_type, depth)
        SELECT
          r1.from_id,
          r2.to_id,
          'hierarchy',
          CASE
            WHEN r1.to_id = r2.from_id
            THEN r1.depth + r2.depth
            ELSE r1.depth + r2.depth + 1
            END
        FROM
          relations r1
        JOIN
          relations r2
        ON
          (r1.to_id = #{from_id} AND r2.from_id = #{to_id})
        OR
          (r1.to_id = r2.from_id AND r1.to_id IN (#{from_id}, #{to_id}))
      SQL
    end

    def memorize_closures_to_destroy
      return unless depth == 1 && relation_type == 'hierarchy'

      @closures_to_destroy = self.class.connection.select_values <<-SQL
        SELECT
          r1.id
        FROM
          relations r1
        JOIN
          relations r2
        ON
          r2.from_id = r1.from_id AND r2.to_id = #{to_id}
        JOIN
          relations r3
        ON
          r3.to_id = r1.to_id AND r3.from_id = #{from_id}
      SQL

      #self.class.connection.execute <<-SQL
      #  DELETE
      #    r1
      #  FROM
      #    relations r1
      #  JOIN
      #    relations r2
      #  ON
      #    r2.from_id = r1.from_id AND r2.to_id = #{to_id}
      #  JOIN
      #    relations r3
      #  ON
      #    r3.to_id = r1.to_id AND r3.from_id = #{from_id}
      #SQL
    end

    def truncate_closures
      return unless @closures_to_destroy && !@closures_to_destroy.empty?

      self.class.where(id: @closures_to_destroy).delete_all

      @closures_to_destroy = nil
    end
  end
end
