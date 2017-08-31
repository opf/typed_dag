class Message < ActiveRecord::Base
  self.inheritance_column = nil

  include TypedDag::Node

  acts_as_dag_node edge_class_name: 'Relation'
end
