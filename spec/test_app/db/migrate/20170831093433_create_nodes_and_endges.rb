class CreateNodesAndEndges < ActiveRecord::Migration[5.1]
  def change
    create_table :messages do |t|
      t.column :text, :string
    end

    create_table :relations do |t|
      t.references :ancestor, null: false
      t.references :descendant, null: false

      t.column :hierarchy, :integer, null: false, default: 0
      t.column :invalidate, :integer, null: false, default: 0

      t.column :count, :integer, null: false, default: 1

      t.index %i(ancestor_id descendant_id hierarchy invalidate), unique: true, name: 'unique_constraint'
    end

    add_foreign_key :relations, :messages, column: :ancestor_id
    add_foreign_key :relations, :messages, column: :descendant_id
  end
end
