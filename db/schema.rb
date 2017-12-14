# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20171214085553) do

  create_table "assets", force: :cascade do |t|
    t.float    "coincheck_jpy"
    t.float    "coincheck_btc"
    t.float    "zaif_jpy"
    t.float    "zaif_btc"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "exchanges_acounts", force: :cascade do |t|
    t.string   "coincheck_api_key"
    t.string   "coincheck_secret_key"
    t.string   "zaif_api_key"
    t.string   "zaif_secret_key"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  create_table "price_diffs", force: :cascade do |t|
    t.float    "profit"
    t.float    "amount"
    t.string   "order"
    t.float    "per1btcProfit"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "profits", force: :cascade do |t|
    t.float    "profit"
    t.float    "amount"
    t.string   "order"
    t.float    "per1BtcProfit"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "values", force: :cascade do |t|
    t.integer  "coincheck_bid"
    t.integer  "coincheck_ask"
    t.integer  "zaif_bid"
    t.integer  "zaif_ask"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

end
