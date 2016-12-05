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

ActiveRecord::Schema.define(version: 20161122160523) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "app_settings", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.string   "value",      limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "app_settings", ["name"], name: "index_app_settings_on_name", using: :btree

  create_table "authorizations", force: :cascade do |t|
    t.string   "provider",      limit: 255
    t.string   "uid",           limit: 255
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "authorized_at"
  end

  add_index "authorizations", ["provider", "uid"], name: "index_authorizations_on_provider_and_uid", using: :btree
  add_index "authorizations", ["user_id"], name: "index_authorizations_on_user_id", using: :btree

  create_table "events", force: :cascade do |t|
    t.integer  "user_id",    null: false
    t.integer  "event_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "events", ["user_id"], name: "index_events_on_user_id", using: :btree

  create_table "identities", force: :cascade do |t|
    t.string   "service_provider",      limit: 255
    t.datetime "last_authenticated_at"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "session_uuid",          limit: 255
    t.string   "uuid",                              null: false
  end

  add_index "identities", ["session_uuid"], name: "index_identities_on_session_uuid", unique: true, using: :btree
  add_index "identities", ["user_id", "service_provider"], name: "index_identities_on_user_id_and_service_provider", using: :btree
  add_index "identities", ["user_id"], name: "index_identities_on_user_id", using: :btree
  add_index "identities", ["uuid"], name: "index_identities_on_uuid", unique: true, using: :btree

  create_table "profiles", force: :cascade do |t|
    t.integer  "user_id",                                           null: false
    t.boolean  "active",                            default: false, null: false
    t.datetime "verified_at"
    t.datetime "activated_at"
    t.datetime "created_at",                                        null: false
    t.datetime "updated_at",                                        null: false
    t.string   "vendor"
    t.text     "encrypted_pii"
    t.string   "ssn_signature",          limit: 64
    t.text     "encrypted_pii_recovery"
    t.integer  "deactivation_reason"
  end

  add_index "profiles", ["ssn_signature", "active"], name: "index_profiles_on_ssn_signature_and_active", unique: true, where: "(active = true)", using: :btree
  add_index "profiles", ["ssn_signature"], name: "index_profiles_on_ssn_signature", using: :btree
  add_index "profiles", ["user_id", "active"], name: "index_profiles_on_user_id_and_active", unique: true, where: "(active = true)", using: :btree
  add_index "profiles", ["user_id", "ssn_signature", "active"], name: "index_profiles_on_user_id_and_ssn_signature_and_active", unique: true, where: "(active = true)", using: :btree
  add_index "profiles", ["user_id"], name: "index_profiles_on_user_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "encrypted_password",            limit: 255, default: ""
    t.string   "reset_password_token",          limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                             default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",            limit: 255
    t.string   "last_sign_in_ip",               limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "confirmation_token",            limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email",             limit: 255
    t.integer  "role"
    t.string   "otp_secret_key",                limit: 255
    t.integer  "second_factor_attempts_count",              default: 0
    t.string   "phone",                         limit: 255
    t.string   "uuid",                          limit: 255,              null: false
    t.datetime "reset_requested_at"
    t.datetime "second_factor_locked_at"
    t.datetime "locked_at"
    t.integer  "failed_attempts",                           default: 0
    t.string   "unlock_token",                  limit: 255
    t.datetime "phone_confirmed_at"
    t.string   "encrypted_otp_secret_key",      limit: 255
    t.string   "encrypted_otp_secret_key_iv",   limit: 255
    t.string   "encrypted_otp_secret_key_salt", limit: 255
    t.string   "direct_otp"
    t.datetime "direct_otp_sent_at"
    t.datetime "idv_attempted_at"
    t.integer  "idv_attempts",                              default: 0
    t.string   "recovery_code"
    t.string   "password_salt"
    t.string   "encryption_key"
    t.string   "unique_session_id"
    t.string   "recovery_salt"
    t.string   "password_cost"
    t.string   "recovery_cost"
    t.string   "email_fingerprint",                         default: "", null: false
    t.text     "encrypted_email",                           default: "", null: false
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
  add_index "users", ["email_fingerprint"], name: "index_users_on_email_fingerprint", unique: true, using: :btree
  add_index "users", ["encrypted_otp_secret_key"], name: "index_users_on_encrypted_otp_secret_key", unique: true, using: :btree
  add_index "users", ["otp_secret_key"], name: "index_users_on_otp_secret_key", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["unconfirmed_email"], name: "index_users_on_unconfirmed_email", using: :btree
  add_index "users", ["unlock_token"], name: "index_users_on_unlock_token", using: :btree
  add_index "users", ["uuid"], name: "index_users_on_uuid", unique: true, using: :btree

  add_foreign_key "events", "users"
end
