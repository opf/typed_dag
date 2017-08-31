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

  create_table "messages", force: :cascade do |t|
  end

  create_table "relations", force: :cascade do |t|
    t.integer "ancestor_id", null: false
    t.integer "descendant_id", null: false
    t.string "type"
    t.integer "depth"
    t.index ["ancestor_id"], name: "index_relations_on_ancestor_id"
    t.index ["depth"], name: "index_relations_on_depth"
    t.index ["descendant_id"], name: "index_relations_on_descendant_id"
    t.index ["type"], name: "index_relations_on_type"
  end

end
