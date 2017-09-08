class Message < ActiveRecord::Base
  self.inheritance_column = nil

  include TypedDag::Node

  acts_as_dag_node edge_class_name: 'Relation',
                   types: { hierarchy: { up: { name: :parent, limit: 1 },
                                         down: :children,
                                         all_up: :ancestors,
                                         all_down: :descendants },
                            invalidate: { up: :invalidated_by,
                                          down: :invalidates,
                                          all_up: :all_invalidated_by,
                                          all_down: :all_invalidates } }
end
