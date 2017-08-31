require 'active_support/concern'

module TypedDag::Node
  extend ActiveSupport::Concern

  included do
    has_one :parent_relation,
            -> {
              where(relations: { relation_type: 'hierarchy',
                                 depth: 1 })
            },
            class_name: 'Relation',
            foreign_key: 'to_id'

    has_one :parent,
            through: :parent_relation,
            source: :from,
            class_name: 'WorkPackage'

    has_many :child_relations,
             -> {
               where(relations: { relation_type: 'hierarchy',
                                  depth: 1 })
             },
             class_name: 'Relation',
             foreign_key: 'from_id'

    has_many :children,
             through: :child_relations,
             source: :to

    has_many :descendant_relations,
             -> { where(relations: { relation_type: 'hierarchy' }) },
             class_name: 'Relation',
             foreign_key: 'from_id'

    has_many :descendants,
             through: :descendant_relations,
             source: :to

    has_many :ancestor_relations,
             -> { where(relations: { relation_type: 'hierarchy' }) },
             class_name: 'Relation',
             foreign_key: 'to_id'

    has_many :ancestors,
             through: :ancestor_relations,
             source: :from

    def leaf?
      !relations_from.where(relation_type: 'hierarchy').exists?
    end

    def child?
      !!parent_relation
    end

    def in_closure?(other_work_package)
      ancestor_relations
        .where(relations: { from_id: other_work_package })
        .or(descendant_relations.where(relations: { to_id: other_work_package }))
        .exists?
    end
  end
end
