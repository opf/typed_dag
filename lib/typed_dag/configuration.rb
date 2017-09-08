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

  def types
    config[:types] || default_types
  end

  def type_columns
    types.keys
  end

  private

  attr_accessor :config

  def default_types
    { hierarchy: { up: { name: :parent, limit: 1 },
                   down: :children,
                   all_up: :ancestors,
                   all_down: :descendants } }
  end
end
