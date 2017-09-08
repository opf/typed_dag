class Relation < ActiveRecord::Base
  include TypedDag::Edge

  acts_as_dag_edge node_class_name: 'Message',
                   types: { hierarchy: { up: { name: :parent, limit: 1 },
                                         down: :children,
                                         all_up: :ancestors,
                                         all_down: :descendants },
                            invalidate: { up: :invalidated_by,
                                          down: :invalidates,
                                          all_up: :all_invalidated_by,
                                          all_down: :all_invalidates } }
end
