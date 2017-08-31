class TypedDag::Configuration
  def initialize(config)
    self.config = config
  end

  def node_class_name
    config[:node_class_name]
  end

  def edge_class_name
    config[:edge_class_name]
  end

  def edge_table_name
    edge_class_name.constantize.table_name
  end

  def ancestor_column
    config[:ancestor_column] || 'ancestor_id'
  end

  def descendant_column
    config[:descendant_column] || 'descendant_id'
  end

  def type_column
    config[:type_column] || 'type'
  end

  def depth_column
    config[:depth_column] || 'depth'
  end

  private

  attr_accessor :config
end
