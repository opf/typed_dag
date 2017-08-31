class CreateNodesAndEndges < ActiveRecord::Migration[5.1]
  def change
    create_table :messages do |t|
    end

    create_table :relations do |t|
      t.references :ancestor, null: false
      t.references :descendant, null: false
      t.column :type, :string
      t.column :depth, :integer

      t.index :depth
      t.index :type
    end

    add_foreign_key :relations, :message, :ancestor
    add_foreign_key :relations, :message, :descendant
  end
end
