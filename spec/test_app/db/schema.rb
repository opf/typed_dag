# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170831093433) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "messages", force: :cascade do |t|
    t.string "text"
  end

  create_table "relations", force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "hierarchy", default: 0, null: false
    t.integer "invalidate", default: 0, null: false
    t.integer "count", default: 0, null: false
    t.index ["ancestor_id", "descendant_id", "hierarchy", "invalidate"], name: "unique_constraint", unique: true
    t.index ["ancestor_id"], name: "index_relations_on_ancestor_id"
    t.index ["descendant_id"], name: "index_relations_on_descendant_id"
  end

  add_foreign_key "relations", "messages", column: "ancestor_id"
  add_foreign_key "relations", "messages", column: "descendant_id"
end
