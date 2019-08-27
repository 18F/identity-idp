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

ActiveRecord::Schema.define(version: 20190826141526) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "account_recovery_requests", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "request_token", null: false
    t.datetime "requested_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_token"], name: "index_account_recovery_requests_on_request_token", unique: true
    t.index ["user_id"], name: "index_account_recovery_requests_on_user_id", unique: true
  end

  create_table "account_reset_requests", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "requested_at"
    t.string "request_token"
    t.datetime "cancelled_at"
    t.datetime "reported_fraud_at"
    t.datetime "granted_at"
    t.string "granted_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cancelled_at", "granted_at", "requested_at"], name: "index_account_reset_requests_on_timestamps"
    t.index ["granted_token"], name: "index_account_reset_requests_on_granted_token", unique: true
    t.index ["request_token"], name: "index_account_reset_requests_on_request_token", unique: true
    t.index ["user_id"], name: "index_account_reset_requests_on_user_id", unique: true
  end

  create_table "agencies", force: :cascade do |t|
    t.string "name", null: false
    t.index ["name"], name: "index_agencies_on_name", unique: true
  end

  create_table "agency_identities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "agency_id", null: false
    t.string "uuid", null: false
    t.index ["user_id", "agency_id"], name: "index_agency_identities_on_user_id_and_agency_id", unique: true
    t.index ["uuid"], name: "index_agency_identities_on_uuid", unique: true
  end

  create_table "authorizations", force: :cascade do |t|
    t.string "provider", limit: 255
    t.string "uid", limit: 255
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "authorized_at"
    t.index ["provider", "uid"], name: "index_authorizations_on_provider_and_uid"
    t.index ["user_id"], name: "index_authorizations_on_user_id"
  end

  create_table "backup_code_configurations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "encrypted_code", default: "", null: false
    t.string "code_fingerprint", default: "", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "code_fingerprint"], name: "index_bcc_on_user_id_code_fingerprint", unique: true
    t.index ["user_id", "created_at"], name: "index_backup_code_configurations_on_user_id_and_created_at"
  end

  create_table "devices", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "cookie_uuid", null: false
    t.string "user_agent", null: false
    t.datetime "last_used_at", null: false
    t.string "last_ip", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "cookie_uuid"], name: "index_device_user_id_cookie_uuid"
    t.index ["user_id", "last_used_at"], name: "index_device_user_id_last_used_at"
  end

  create_table "doc_auths", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "attempted_at"
    t.integer "attempts", default: 0
    t.datetime "license_confirmed_at"
    t.datetime "selfie_confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_doc_auths_on_user_id"
  end

  create_table "doc_captures", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "request_token", null: false
    t.datetime "requested_at", null: false
    t.string "acuant_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_token"], name: "index_doc_captures_on_request_token", unique: true
    t.index ["user_id"], name: "index_doc_captures_on_user_id", unique: true
  end

  create_table "email_addresses", force: :cascade do |t|
    t.bigint "user_id"
    t.string "confirmation_token", limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "email_fingerprint", default: "", null: false
    t.string "encrypted_email", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_sign_in_at"
    t.index ["confirmation_token"], name: "index_email_addresses_on_confirmation_token", unique: true
    t.index ["email_fingerprint"], name: "index_email_addresses_on_all_email_fingerprints"
    t.index ["email_fingerprint"], name: "index_email_addresses_on_email_fingerprint", unique: true, where: "(confirmed_at IS NOT NULL)"
    t.index ["user_id", "last_sign_in_at"], name: "index_email_addresses_on_user_id_and_last_sign_in_at", order: { last_sign_in_at: :desc }
    t.index ["user_id"], name: "index_email_addresses_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "event_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "device_id"
    t.string "ip"
    t.datetime "disavowed_at"
    t.string "disavowal_token_fingerprint"
    t.index ["device_id", "created_at"], name: "index_events_on_device_id_and_created_at"
    t.index ["disavowal_token_fingerprint"], name: "index_events_on_disavowal_token_fingerprint"
    t.index ["user_id", "created_at"], name: "index_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "identities", force: :cascade do |t|
    t.string "service_provider", limit: 255
    t.datetime "last_authenticated_at"
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "session_uuid", limit: 255
    t.string "uuid", null: false
    t.string "nonce"
    t.integer "ial", default: 1
    t.string "access_token"
    t.string "scope"
    t.string "code_challenge"
    t.string "rails_session_id"
    t.json "verified_attributes"
    t.index ["access_token"], name: "index_identities_on_access_token", unique: true
    t.index ["session_uuid"], name: "index_identities_on_session_uuid", unique: true
    t.index ["user_id", "service_provider"], name: "index_identities_on_user_id_and_service_provider", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
    t.index ["uuid"], name: "index_identities_on_uuid", unique: true
  end

  create_table "job_runs", force: :cascade do |t|
    t.string "host", null: false
    t.string "pid", null: false
    t.datetime "finish_time"
    t.string "job_name", null: false
    t.string "result"
    t.string "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["error"], name: "index_job_runs_on_error"
    t.index ["host"], name: "index_job_runs_on_host"
    t.index ["job_name", "created_at"], name: "index_job_runs_on_job_name_and_created_at"
    t.index ["job_name", "finish_time"], name: "index_job_runs_on_job_name_and_finish_time"
    t.index ["job_name"], name: "index_job_runs_on_job_name"
  end

  create_table "monthly_auth_counts", force: :cascade do |t|
    t.string "issuer", null: false
    t.string "year_month", null: false
    t.integer "user_id", null: false
    t.integer "auth_count", default: 1, null: false
    t.index ["issuer", "year_month", "user_id"], name: "index_monthly_auth_counts_on_issuer_and_year_month_and_user_id", unique: true
  end

  create_table "otp_requests_trackers", force: :cascade do |t|
    t.datetime "otp_last_sent_at"
    t.integer "otp_send_count", default: 0
    t.string "attribute_cost"
    t.string "phone_fingerprint", default: "", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["phone_fingerprint"], name: "index_otp_requests_trackers_on_phone_fingerprint", unique: true
    t.index ["updated_at"], name: "index_otp_requests_trackers_on_updated_at"
  end

  create_table "phone_configurations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "encrypted_phone", null: false
    t.integer "delivery_preference", default: 0, null: false
    t.boolean "mfa_enabled", default: true, null: false
    t.datetime "confirmation_sent_at"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "made_default_at"
    t.index ["user_id", "made_default_at", "created_at"], name: "index_phone_configurations_on_made_default_at"
    t.index ["user_id"], name: "index_phone_configurations_on_user_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.integer "user_id", null: false
    t.boolean "active", default: false, null: false
    t.datetime "verified_at"
    t.datetime "activated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "encrypted_pii"
    t.string "ssn_signature", limit: 64
    t.text "encrypted_pii_recovery"
    t.integer "deactivation_reason"
    t.boolean "phone_confirmed", default: false, null: false
    t.index ["ssn_signature", "active"], name: "index_profiles_on_ssn_signature_and_active", unique: true, where: "(active = true)"
    t.index ["ssn_signature"], name: "index_profiles_on_ssn_signature"
    t.index ["user_id", "active"], name: "index_profiles_on_user_id_and_active", unique: true, where: "(active = true)"
    t.index ["user_id", "ssn_signature", "active"], name: "index_profiles_on_user_id_and_ssn_signature_and_active", unique: true, where: "(active = true)"
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "push_account_deletes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "agency_id", null: false
    t.string "uuid", null: false
    t.index ["created_at"], name: "index_push_account_deletes_on_created_at"
  end

  create_table "registration_logs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "submitted_at", null: false
    t.datetime "confirmed_at"
    t.datetime "password_at"
    t.string "first_mfa"
    t.datetime "first_mfa_at"
    t.string "second_mfa"
    t.datetime "registered_at"
    t.index ["registered_at"], name: "index_registration_logs_on_registered_at"
    t.index ["submitted_at"], name: "index_registration_logs_on_submitted_at"
    t.index ["user_id"], name: "index_registration_logs_on_user_id", unique: true
  end

  create_table "remote_settings", force: :cascade do |t|
    t.string "name", null: false
    t.string "url", null: false
    t.text "contents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_remote_settings_on_name", unique: true
  end

  create_table "service_provider_requests", force: :cascade do |t|
    t.string "issuer", null: false
    t.string "loa", null: false
    t.string "url", null: false
    t.string "uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "requested_attributes", default: [], array: true
    t.index ["uuid"], name: "index_service_provider_requests_on_uuid", unique: true
  end

  create_table "service_providers", force: :cascade do |t|
    t.string "issuer", null: false
    t.string "friendly_name"
    t.text "description"
    t.text "metadata_url"
    t.text "acs_url"
    t.text "assertion_consumer_logout_service_url"
    t.text "cert"
    t.text "logo"
    t.string "fingerprint"
    t.string "signature"
    t.string "block_encryption", default: "aes256-cbc", null: false
    t.text "sp_initiated_login_url"
    t.text "return_to_sp_url"
    t.string "agency"
    t.json "attribute_bundle"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "active", default: false, null: false
    t.boolean "approved", default: false, null: false
    t.boolean "native", default: false, null: false
    t.string "redirect_uris", default: [], array: true
    t.integer "agency_id"
    t.text "failure_to_proof_url"
    t.integer "aal"
    t.integer "ial"
    t.boolean "piv_cac", default: false
    t.boolean "piv_cac_scoped_by_email", default: false
    t.boolean "pkce"
    t.string "push_notification_url"
    t.index ["issuer"], name: "index_service_providers_on_issuer", unique: true
  end

  create_table "throttles", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "throttle_type", null: false
    t.datetime "attempted_at"
    t.integer "attempts", default: 0
    t.integer "throttled_count"
    t.index ["user_id", "throttle_type"], name: "index_throttles_on_user_id_and_throttle_type"
  end

  create_table "users", force: :cascade do |t|
    t.string "reset_password_token", limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip", limit: 255
    t.string "last_sign_in_ip", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "confirmation_token", limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email", limit: 255
    t.integer "second_factor_attempts_count", default: 0
    t.string "uuid", limit: 255, null: false
    t.datetime "second_factor_locked_at"
    t.datetime "locked_at"
    t.integer "failed_attempts", default: 0
    t.string "unlock_token", limit: 255
    t.datetime "phone_confirmed_at"
    t.text "encrypted_otp_secret_key"
    t.string "direct_otp"
    t.datetime "direct_otp_sent_at"
    t.datetime "idv_attempted_at"
    t.integer "idv_attempts", default: 0
    t.string "unique_session_id"
    t.string "email_fingerprint", default: "", null: false
    t.text "encrypted_email", default: "", null: false
    t.string "attribute_cost"
    t.text "encrypted_phone"
    t.integer "otp_delivery_preference", default: 0, null: false
    t.integer "totp_timestamp"
    t.string "x509_dn_uuid"
    t.string "encrypted_password_digest", default: ""
    t.string "encrypted_recovery_code_digest", default: ""
    t.datetime "remember_device_revoked_at"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["encrypted_otp_secret_key"], name: "index_users_on_encrypted_otp_secret_key", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unconfirmed_email"], name: "index_users_on_unconfirmed_email"
    t.index ["unlock_token"], name: "index_users_on_unlock_token"
    t.index ["uuid"], name: "index_users_on_uuid", unique: true
    t.index ["x509_dn_uuid"], name: "index_users_on_x509_dn_uuid", unique: true
  end

  create_table "usps_confirmation_codes", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "otp_fingerprint", null: false
    t.datetime "code_sent_at", default: -> { "now()" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "bounced_at"
    t.datetime "letter_expired_sent_at"
    t.index ["bounced_at", "letter_expired_sent_at", "created_at"], name: "index_ucc_expired_letters"
    t.index ["otp_fingerprint"], name: "index_usps_confirmation_codes_on_otp_fingerprint"
    t.index ["profile_id"], name: "index_usps_confirmation_codes_on_profile_id"
  end

  create_table "usps_confirmations", force: :cascade do |t|
    t.text "entry", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "webauthn_configurations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "credential_id", null: false
    t.text "credential_public_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_webauthn_configurations_on_user_id"
  end

  add_foreign_key "events", "users"
end
