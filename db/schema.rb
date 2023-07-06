# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2023_06_27_213457) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_stat_statements"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "account_reset_requests", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "requested_at", precision: nil
    t.string "request_token"
    t.datetime "cancelled_at", precision: nil
    t.datetime "reported_fraud_at", precision: nil
    t.datetime "granted_at", precision: nil
    t.string "granted_token"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "requesting_issuer"
    t.index ["cancelled_at", "granted_at", "requested_at"], name: "index_account_reset_requests_on_timestamps"
    t.index ["granted_token"], name: "index_account_reset_requests_on_granted_token", unique: true
    t.index ["request_token"], name: "index_account_reset_requests_on_request_token", unique: true
    t.index ["user_id"], name: "index_account_reset_requests_on_user_id", unique: true
  end

  create_table "agencies", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation"
    t.index ["abbreviation"], name: "index_agencies_on_abbreviation", unique: true
    t.index ["name"], name: "index_agencies_on_name", unique: true
    t.check_constraint "abbreviation IS NOT NULL", name: "agencies_abbreviation_null"
  end

  create_table "agency_identities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "agency_id", null: false
    t.string "uuid", null: false
    t.index ["user_id", "agency_id"], name: "index_agency_identities_on_user_id_and_agency_id", unique: true
    t.index ["uuid"], name: "index_agency_identities_on_uuid", unique: true
  end

  create_table "auth_app_configurations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "encrypted_otp_secret_key", null: false
    t.string "name", null: false
    t.integer "totp_timestamp"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["user_id", "created_at"], name: "index_auth_app_configurations_on_user_id_and_created_at", unique: true
    t.index ["user_id", "name"], name: "index_auth_app_configurations_on_user_id_and_name", unique: true
  end

  create_table "backup_code_configurations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "used_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "salted_code_fingerprint"
    t.string "code_salt"
    t.string "code_cost"
    t.index ["user_id", "created_at"], name: "index_backup_code_configurations_on_user_id_and_created_at"
    t.index ["user_id", "salted_code_fingerprint"], name: "index_backup_codes_on_user_id_and_salted_code_fingerprint"
  end

  create_table "deleted_users", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "uuid", null: false
    t.datetime "user_created_at", precision: nil, null: false
    t.datetime "deleted_at", precision: nil, null: false
    t.index ["user_id"], name: "index_deleted_users_on_user_id", unique: true
    t.index ["uuid"], name: "index_deleted_users_on_uuid", unique: true
  end

  create_table "devices", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "cookie_uuid", null: false
    t.string "user_agent", null: false
    t.datetime "last_used_at", precision: nil, null: false
    t.string "last_ip", limit: 255, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["cookie_uuid"], name: "index_devices_on_cookie_uuid"
    t.index ["user_id", "last_used_at"], name: "index_device_user_id_last_used_at"
  end

  create_table "doc_auth_logs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "welcome_view_at", precision: nil
    t.integer "welcome_view_count", default: 0
    t.datetime "upload_view_at", precision: nil
    t.integer "upload_view_count", default: 0
    t.datetime "link_sent_view_at", precision: nil
    t.integer "link_sent_view_count", default: 0
    t.datetime "front_image_view_at", precision: nil
    t.integer "front_image_view_count", default: 0
    t.integer "front_image_submit_count", default: 0
    t.integer "front_image_error_count", default: 0
    t.datetime "back_image_view_at", precision: nil
    t.integer "back_image_view_count", default: 0
    t.integer "back_image_submit_count", default: 0
    t.integer "back_image_error_count", default: 0
    t.datetime "mobile_front_image_view_at", precision: nil
    t.integer "mobile_front_image_view_count", default: 0
    t.datetime "mobile_back_image_view_at", precision: nil
    t.integer "mobile_back_image_view_count", default: 0
    t.datetime "ssn_view_at", precision: nil
    t.integer "ssn_view_count", default: 0
    t.datetime "verify_view_at", precision: nil
    t.integer "verify_view_count", default: 0
    t.integer "verify_submit_count", default: 0
    t.integer "verify_error_count", default: 0
    t.datetime "verify_phone_view_at", precision: nil
    t.integer "verify_phone_view_count", default: 0
    t.datetime "usps_address_view_at", precision: nil
    t.integer "usps_address_view_count", default: 0
    t.datetime "encrypt_view_at", precision: nil
    t.integer "encrypt_view_count", default: 0
    t.datetime "verified_view_at", precision: nil
    t.integer "verified_view_count", default: 0
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "mobile_front_image_submit_count", default: 0
    t.integer "mobile_front_image_error_count", default: 0
    t.integer "mobile_back_image_submit_count", default: 0
    t.integer "mobile_back_image_error_count", default: 0
    t.integer "usps_letter_sent_submit_count", default: 0
    t.integer "usps_letter_sent_error_count", default: 0
    t.datetime "capture_mobile_back_image_view_at", precision: nil
    t.integer "capture_mobile_back_image_view_count", default: 0
    t.datetime "capture_complete_view_at", precision: nil
    t.integer "capture_complete_view_count", default: 0
    t.integer "capture_mobile_back_image_submit_count", default: 0
    t.integer "capture_mobile_back_image_error_count", default: 0
    t.datetime "no_sp_session_started_at", precision: nil
    t.datetime "choose_method_view_at", precision: nil
    t.integer "choose_method_view_count", default: 0
    t.datetime "present_cac_view_at", precision: nil
    t.integer "present_cac_view_count", default: 0
    t.integer "present_cac_submit_count", default: 0
    t.integer "present_cac_error_count", default: 0
    t.datetime "enter_info_view_at", precision: nil
    t.integer "enter_info_view_count", default: 0
    t.datetime "success_view_at", precision: nil
    t.integer "success_view_count", default: 0
    t.integer "selfie_view_count", default: 0
    t.integer "selfie_submit_count", default: 0
    t.integer "selfie_error_count", default: 0
    t.string "issuer"
    t.string "last_document_error"
    t.datetime "document_capture_view_at", precision: nil
    t.integer "document_capture_view_count", default: 0
    t.integer "document_capture_submit_count", default: 0
    t.integer "document_capture_error_count", default: 0
    t.datetime "agreement_view_at", precision: nil
    t.integer "agreement_view_count", default: 0
    t.string "state"
    t.boolean "aamva"
    t.datetime "verify_submit_at", precision: nil
    t.integer "verify_phone_submit_count", default: 0
    t.datetime "verify_phone_submit_at", precision: nil
    t.datetime "document_capture_submit_at", precision: nil
    t.datetime "back_image_submit_at", precision: nil
    t.datetime "capture_mobile_back_image_submit_at", precision: nil
    t.datetime "mobile_back_image_submit_at", precision: nil
    t.index ["issuer"], name: "index_doc_auth_logs_on_issuer"
    t.index ["user_id"], name: "index_doc_auth_logs_on_user_id", unique: true
    t.index ["verified_view_at"], name: "index_doc_auth_logs_on_verified_view_at"
  end

  create_table "document_capture_sessions", force: :cascade do |t|
    t.string "uuid"
    t.string "result_id"
    t.bigint "user_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "requested_at", precision: nil
    t.string "issuer"
    t.datetime "cancelled_at", precision: nil
    t.boolean "ocr_confirmation_pending", default: false
    t.index ["result_id"], name: "index_document_capture_sessions_on_result_id"
    t.index ["user_id"], name: "index_document_capture_sessions_on_user_id"
    t.index ["uuid"], name: "index_document_capture_sessions_on_uuid"
  end

  create_table "email_addresses", force: :cascade do |t|
    t.bigint "user_id"
    t.string "confirmation_token", limit: 255
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "email_fingerprint", default: "", null: false
    t.string "encrypted_email", default: "", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "last_sign_in_at", precision: nil
    t.index ["confirmation_token"], name: "index_email_addresses_on_confirmation_token", unique: true
    t.index ["email_fingerprint", "user_id"], name: "index_email_addresses_on_email_fingerprint_and_user_id", unique: true
    t.index ["email_fingerprint"], name: "index_email_addresses_on_email_fingerprint", unique: true, where: "(confirmed_at IS NOT NULL)"
    t.index ["user_id"], name: "index_email_addresses_on_user_id"
  end

  create_table "events", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "event_type", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "device_id"
    t.string "ip"
    t.datetime "disavowed_at", precision: nil
    t.string "disavowal_token_fingerprint"
    t.index ["device_id", "created_at"], name: "index_events_on_device_id_and_created_at"
    t.index ["disavowal_token_fingerprint"], name: "index_events_on_disavowal_token_fingerprint"
    t.index ["user_id", "created_at"], name: "index_events_on_user_id_and_created_at"
  end

  create_table "fraud_review_requests", force: :cascade do |t|
    t.integer "user_id"
    t.string "uuid"
    t.string "irs_session_id"
    t.string "login_session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_fraud_review_requests_on_user_id"
  end

  create_table "iaa_gtcs", force: :cascade do |t|
    t.string "gtc_number", null: false
    t.integer "mod_number", default: 0, null: false
    t.date "start_date"
    t.date "end_date"
    t.decimal "estimated_amount", precision: 12, scale: 2
    t.bigint "partner_account_id"
    t.index ["gtc_number"], name: "index_iaa_gtcs_on_gtc_number", unique: true
    t.index ["partner_account_id"], name: "index_iaa_gtcs_on_partner_account_id"
    t.check_constraint "end_date IS NOT NULL", name: "iaa_gtcs_end_date_null"
    t.check_constraint "start_date IS NOT NULL", name: "iaa_gtcs_start_date_null"
  end

  create_table "iaa_orders", force: :cascade do |t|
    t.integer "order_number", null: false
    t.integer "mod_number", default: 0, null: false
    t.date "start_date"
    t.date "end_date"
    t.decimal "estimated_amount", precision: 12, scale: 2
    t.integer "pricing_model", default: 2, null: false
    t.bigint "iaa_gtc_id"
    t.index ["iaa_gtc_id", "order_number"], name: "index_iaa_orders_on_iaa_gtc_id_and_order_number", unique: true
    t.index ["iaa_gtc_id"], name: "index_iaa_orders_on_iaa_gtc_id"
    t.check_constraint "end_date IS NOT NULL", name: "iaa_orders_end_date_null"
    t.check_constraint "start_date IS NOT NULL", name: "iaa_orders_start_date_null"
  end

  create_table "identities", id: :serial, force: :cascade do |t|
    t.string "service_provider", limit: 255
    t.datetime "last_authenticated_at", precision: nil
    t.integer "user_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "session_uuid", limit: 255
    t.string "uuid", null: false
    t.string "nonce"
    t.integer "ial", default: 1
    t.string "access_token"
    t.string "scope"
    t.string "code_challenge"
    t.string "rails_session_id"
    t.json "verified_attributes"
    t.datetime "verified_at", precision: nil
    t.datetime "last_consented_at", precision: nil
    t.datetime "last_ial1_authenticated_at", precision: nil
    t.datetime "last_ial2_authenticated_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.integer "aal"
    t.text "requested_aal_value"
    t.index ["access_token"], name: "index_identities_on_access_token", unique: true
    t.index ["session_uuid"], name: "index_identities_on_session_uuid", unique: true
    t.index ["user_id", "service_provider"], name: "index_identities_on_user_id_and_service_provider", unique: true
    t.index ["uuid"], name: "index_identities_on_uuid", unique: true
  end

  create_table "in_person_enrollments", comment: "Details and status of an in-person proofing enrollment for one user and profile", force: :cascade do |t|
    t.bigint "user_id", null: false, comment: "Foreign key to the user this enrollment belongs to"
    t.bigint "profile_id", comment: "Foreign key to the profile this enrollment belongs to"
    t.string "enrollment_code", comment: "The code returned by the USPS service"
    t.datetime "status_check_attempted_at", precision: nil, comment: "The last time a status check was attempted"
    t.datetime "status_updated_at", precision: nil, comment: "The last time the status was successfully updated with a value from the USPS API"
    t.integer "status", default: 0, comment: "The status of the enrollment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "current_address_matches_id", comment: "True if the user indicates that their current address matches the address on the ID they're bringing to the Post Office."
    t.jsonb "selected_location_details", comment: "The location details of the Post Office the user selected (including title, address, hours of operation)"
    t.string "unique_id", comment: "Unique ID to use with the USPS service"
    t.datetime "enrollment_established_at", comment: "When the enrollment was successfully established"
    t.string "issuer", comment: "Issuer associated with the enrollment at time of creation"
    t.boolean "follow_up_survey_sent", default: false
    t.boolean "early_reminder_sent", default: false, comment: "early reminder to complete IPP before deadline sent"
    t.boolean "late_reminder_sent", default: false, comment: "late reminder to complete IPP before deadline sent"
    t.boolean "deadline_passed_sent", default: false, comment: "deadline passed email sent for expired enrollment"
    t.datetime "proofed_at", precision: nil, comment: "timestamp when user attempted to proof at a Post Office"
    t.boolean "capture_secondary_id_enabled", default: false, comment: "record and proof state ID and residential addresses separately"
    t.datetime "status_check_completed_at", comment: "The last time a status check was successfully completed"
    t.boolean "ready_for_status_check", default: false
    t.index ["profile_id"], name: "index_in_person_enrollments_on_profile_id"
    t.index ["ready_for_status_check"], name: "index_in_person_enrollments_on_ready_for_status_check", where: "(ready_for_status_check = true)"
    t.index ["status_check_attempted_at"], name: "index_in_person_enrollments_on_status_check_attempted_at", where: "(status = 1)"
    t.index ["unique_id"], name: "index_in_person_enrollments_on_unique_id", unique: true
    t.index ["user_id", "status"], name: "index_in_person_enrollments_on_user_id_and_status", unique: true, where: "(status = 1)"
    t.index ["user_id"], name: "index_in_person_enrollments_on_user_id"
  end

  create_table "integration_statuses", force: :cascade do |t|
    t.string "name", null: false
    t.integer "order", null: false
    t.string "partner_name"
    t.index ["name"], name: "index_integration_statuses_on_name", unique: true
    t.index ["order"], name: "index_integration_statuses_on_order", unique: true
  end

  create_table "integration_usages", force: :cascade do |t|
    t.bigint "iaa_order_id"
    t.bigint "integration_id"
    t.index ["iaa_order_id", "integration_id"], name: "index_integration_usages_on_iaa_order_id_and_integration_id", unique: true
    t.index ["iaa_order_id"], name: "index_integration_usages_on_iaa_order_id"
    t.index ["integration_id"], name: "index_integration_usages_on_integration_id"
  end

  create_table "integrations", force: :cascade do |t|
    t.string "issuer", null: false
    t.string "name", null: false
    t.integer "dashboard_identifier"
    t.bigint "partner_account_id"
    t.bigint "integration_status_id"
    t.bigint "service_provider_id"
    t.index ["dashboard_identifier"], name: "index_integrations_on_dashboard_identifier", unique: true
    t.index ["integration_status_id"], name: "index_integrations_on_integration_status_id"
    t.index ["issuer"], name: "index_integrations_on_issuer", unique: true
    t.index ["partner_account_id"], name: "index_integrations_on_partner_account_id"
    t.index ["service_provider_id"], name: "index_integrations_on_service_provider_id"
  end

  create_table "letter_requests_to_usps_ftp_logs", force: :cascade do |t|
    t.datetime "ftp_at", precision: nil, null: false
    t.integer "letter_requests_count", null: false
    t.index ["ftp_at"], name: "index_letter_requests_to_usps_ftp_logs_on_ftp_at"
  end

  create_table "monthly_auth_counts", force: :cascade do |t|
    t.string "issuer", null: false
    t.string "year_month", null: false
    t.integer "user_id", null: false
    t.integer "auth_count", default: 1, null: false
    t.index ["issuer", "year_month", "user_id"], name: "index_monthly_auth_counts_on_issuer_and_year_month_and_user_id", unique: true
  end

  create_table "notification_phone_configurations", force: :cascade do |t|
    t.bigint "in_person_enrollment_id", null: false
    t.text "encrypted_phone", null: false, comment: "Encrypted phone number to send notifications to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["in_person_enrollment_id"], name: "index_notification_phone_configurations_on_enrollment_id", unique: true
  end

  create_table "partner_account_statuses", force: :cascade do |t|
    t.string "name", null: false
    t.integer "order", null: false
    t.string "partner_name"
    t.index ["name"], name: "index_partner_account_statuses_on_name", unique: true
    t.index ["order"], name: "index_partner_account_statuses_on_order", unique: true
  end

  create_table "partner_accounts", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "requesting_agency", null: false
    t.date "became_partner"
    t.bigint "agency_id"
    t.bigint "partner_account_status_id"
    t.bigint "crm_id"
    t.index ["agency_id"], name: "index_partner_accounts_on_agency_id"
    t.index ["name"], name: "index_partner_accounts_on_name", unique: true
    t.index ["partner_account_status_id"], name: "index_partner_accounts_on_partner_account_status_id"
    t.index ["requesting_agency"], name: "index_partner_accounts_on_requesting_agency", unique: true
  end

  create_table "phone_configurations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "encrypted_phone", null: false
    t.integer "delivery_preference", default: 0, null: false
    t.boolean "mfa_enabled", default: true, null: false
    t.datetime "confirmation_sent_at", precision: nil
    t.datetime "confirmed_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "made_default_at", precision: nil
    t.index ["user_id", "made_default_at", "created_at"], name: "index_phone_configurations_on_made_default_at"
  end

  create_table "phone_number_opt_outs", force: :cascade do |t|
    t.string "encrypted_phone"
    t.string "phone_fingerprint", null: false
    t.string "uuid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["phone_fingerprint"], name: "index_phone_number_opt_outs_on_phone_fingerprint", unique: true
    t.index ["uuid"], name: "index_phone_number_opt_outs_on_uuid", unique: true
  end

  create_table "piv_cac_configurations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "x509_dn_uuid", null: false
    t.string "name", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "x509_issuer"
    t.index ["user_id", "created_at"], name: "index_piv_cac_configurations_on_user_id_and_created_at", unique: true
    t.index ["user_id", "name"], name: "index_piv_cac_configurations_on_user_id_and_name", unique: true
    t.index ["x509_dn_uuid"], name: "index_piv_cac_configurations_on_x509_dn_uuid", unique: true
  end

  create_table "profiles", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.boolean "active", default: false, null: false
    t.datetime "verified_at", precision: nil
    t.datetime "activated_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "encrypted_pii"
    t.string "ssn_signature", limit: 64
    t.text "encrypted_pii_recovery"
    t.integer "deactivation_reason"
    t.jsonb "proofing_components"
    t.string "name_zip_birth_year_signature"
    t.date "reproof_at"
    t.string "initiating_service_provider_issuer"
    t.datetime "fraud_review_pending_at"
    t.datetime "fraud_rejection_at"
    t.datetime "gpo_verification_pending_at"
    t.integer "fraud_pending_reason"
    t.index ["fraud_pending_reason"], name: "index_profiles_on_fraud_pending_reason"
    t.index ["fraud_rejection_at"], name: "index_profiles_on_fraud_rejection_at"
    t.index ["fraud_review_pending_at"], name: "index_profiles_on_fraud_review_pending_at"
    t.index ["gpo_verification_pending_at"], name: "index_profiles_on_gpo_verification_pending_at"
    t.index ["name_zip_birth_year_signature"], name: "index_profiles_on_name_zip_birth_year_signature"
    t.index ["reproof_at"], name: "index_profiles_on_reproof_at"
    t.index ["ssn_signature"], name: "index_profiles_on_ssn_signature"
    t.index ["user_id", "active"], name: "index_profiles_on_user_id_and_active", unique: true, where: "(active = true)"
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "proofing_components", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "document_check"
    t.string "document_type"
    t.string "source_check"
    t.string "resolution_check"
    t.string "address_check"
    t.datetime "verified_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "liveness_check"
    t.string "device_fingerprinting_vendor"
    t.boolean "threatmetrix"
    t.string "threatmetrix_review_status"
    t.string "threatmetrix_risk_rating"
    t.string "threatmetrix_policy_score"
    t.index ["user_id"], name: "index_proofing_components_on_user_id", unique: true
    t.index ["verified_at"], name: "index_proofing_components_on_verified_at"
  end

  create_table "registration_logs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "registered_at", precision: nil
    t.index ["registered_at"], name: "index_registration_logs_on_registered_at"
    t.index ["user_id"], name: "index_registration_logs_on_user_id", unique: true
  end

  create_table "security_events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "event_type", null: false
    t.string "jti"
    t.string "issuer"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "occurred_at", precision: nil
    t.index ["jti", "user_id", "issuer"], name: "index_security_events_on_jti_and_user_id_and_issuer", unique: true
    t.index ["user_id"], name: "index_security_events_on_user_id"
  end

  create_table "service_providers", id: :serial, force: :cascade do |t|
    t.string "issuer", null: false
    t.string "friendly_name"
    t.text "description"
    t.text "metadata_url"
    t.text "acs_url"
    t.text "assertion_consumer_logout_service_url"
    t.text "logo"
    t.string "signature"
    t.string "block_encryption", default: "aes256-cbc", null: false
    t.text "sp_initiated_login_url"
    t.text "return_to_sp_url"
    t.json "attribute_bundle"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "active", default: false, null: false
    t.boolean "approved", default: false, null: false
    t.boolean "native", default: false, null: false
    t.string "redirect_uris", default: [], array: true
    t.integer "agency_id"
    t.text "failure_to_proof_url"
    t.integer "ial"
    t.boolean "piv_cac", default: false
    t.boolean "piv_cac_scoped_by_email", default: false
    t.boolean "pkce"
    t.string "push_notification_url"
    t.jsonb "help_text", default: {"sign_in"=>{}, "sign_up"=>{}, "forgot_password"=>{}}
    t.boolean "allow_prompt_login", default: false
    t.boolean "signed_response_message_requested", default: false
    t.string "remote_logo_key"
    t.date "launch_date"
    t.string "iaa"
    t.date "iaa_start_date"
    t.date "iaa_end_date"
    t.string "app_id"
    t.integer "default_aal"
    t.string "certs", array: true
    t.boolean "email_nameid_format_allowed", default: false
    t.boolean "use_legacy_name_id_behavior", default: false
    t.boolean "irs_attempts_api_enabled"
    t.boolean "in_person_proofing_enabled", default: false
    t.index ["issuer"], name: "index_service_providers_on_issuer", unique: true
  end

  create_table "sign_in_restrictions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "service_provider"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "service_provider"], name: "index_sign_in_restrictions_on_user_id_and_service_provider", unique: true
  end

  create_table "sp_costs", force: :cascade do |t|
    t.string "issuer", null: false
    t.integer "agency_id", null: false
    t.string "cost_type", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "ial"
    t.string "transaction_id"
    t.index ["created_at"], name: "index_sp_costs_on_created_at"
  end

  create_table "sp_return_logs", force: :cascade do |t|
    t.datetime "requested_at", precision: nil, null: false
    t.string "request_id", null: false
    t.integer "ial", null: false
    t.string "issuer", null: false
    t.integer "user_id"
    t.datetime "returned_at", precision: nil
    t.boolean "billable"
    t.index "((returned_at)::date), issuer", name: "index_sp_return_logs_on_returned_at_date_issuer", where: "((billable = true) AND (returned_at IS NOT NULL))"
    t.index ["request_id"], name: "index_sp_return_logs_on_request_id", unique: true
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "reset_password_token", limit: 255
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.datetime "confirmed_at", precision: nil
    t.integer "second_factor_attempts_count", default: 0
    t.string "uuid", limit: 255, null: false
    t.datetime "second_factor_locked_at", precision: nil
    t.datetime "phone_confirmed_at", precision: nil
    t.string "direct_otp"
    t.datetime "direct_otp_sent_at", precision: nil
    t.string "unique_session_id"
    t.integer "otp_delivery_preference", default: 0, null: false
    t.string "encrypted_password_digest", default: ""
    t.string "encrypted_recovery_code_digest", default: ""
    t.datetime "remember_device_revoked_at", precision: nil
    t.string "email_language", limit: 10
    t.datetime "accepted_terms_at", precision: nil
    t.datetime "encrypted_recovery_code_digest_generated_at", precision: nil
    t.datetime "suspended_at"
    t.datetime "reinstated_at"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uuid"], name: "index_users_on_uuid", unique: true
  end

  create_table "usps_confirmation_codes", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "otp_fingerprint", null: false
    t.datetime "code_sent_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "bounced_at", precision: nil
    t.index ["otp_fingerprint"], name: "index_usps_confirmation_codes_on_otp_fingerprint"
    t.index ["profile_id"], name: "index_usps_confirmation_codes_on_profile_id"
  end

  create_table "usps_confirmations", id: :serial, force: :cascade do |t|
    t.text "entry", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "webauthn_configurations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "credential_id", null: false
    t.text "credential_public_key", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "platform_authenticator"
    t.string "transports", array: true
    t.index ["user_id"], name: "index_webauthn_configurations_on_user_id"
  end

  add_foreign_key "document_capture_sessions", "users"
  add_foreign_key "iaa_gtcs", "partner_accounts"
  add_foreign_key "iaa_orders", "iaa_gtcs"
  add_foreign_key "in_person_enrollments", "profiles"
  add_foreign_key "in_person_enrollments", "service_providers", column: "issuer", primary_key: "issuer"
  add_foreign_key "in_person_enrollments", "users"
  add_foreign_key "integration_usages", "iaa_orders"
  add_foreign_key "integration_usages", "integrations"
  add_foreign_key "integrations", "integration_statuses"
  add_foreign_key "integrations", "partner_accounts"
  add_foreign_key "integrations", "service_providers"
  add_foreign_key "partner_accounts", "agencies"
  add_foreign_key "partner_accounts", "partner_account_statuses"
end
