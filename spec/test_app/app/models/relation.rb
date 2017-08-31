class Relation < ActiveRecord::Base
  include TypedDag::Edge

  acts_as_dag_edge node_class_name: 'Message'
end
