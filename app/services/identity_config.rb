class IdentityConfig
  class << self
    attr_reader :store
  end

  CONVERTERS = {
    uri: -> (value) { URI(value) if value.present? },
    string: -> (value) { value },
    comma_separated_string_list: -> (value) do
      value.split(',')
    end,
    integer: -> (value) do
      Integer(value)
    end,
    json: -> (value) do
      JSON.parse(value)
    end,
    boolean: -> (value) do
      case value
      when 'true'
        true
      when 'false'
        false
      else
        raise 'invalid boolean value'
      end
    end,
  }

  def initialize(read_env)
    @read_env = read_env
    @written_env = {}
  end

  # Dependency injection is required
  def add(key, type: :string, is_sensitive: false)
    value = @read_env[key]
    raise "#{key} is required but is not present" if value.nil?
    converted_value = CONVERTERS.fetch(type).call(value)
    raise "#{key} is required but is not present" if converted_value.nil?

    @written_env[key] = converted_value
    @written_env
  end

  def self.build_settings(config_map)
    config = IdentityConfig.new(config_map)

    config.add(:aal_authn_context_enabled, type: :boolean)
    config.add(:aamva_cert_enabled, type: :boolean)
    config.add(:aamva_private_key)
    config.add(:aamva_public_key)
    config.add(:aamva_sp_banlist_issuers, type: :json)
    config.add(:aamva_verification_url, type: :uri)
    config.add(:account_reset_auth_token)
    config.add(:account_reset_token_valid_for_days, type: :integer)
    config.add(:account_reset_wait_period_days, type: :integer)
    config.add(:acuant_assure_id_password)
    config.add(:acuant_assure_id_subscription_id)
    config.add(:acuant_assure_id_url, type: :uri)
    config.add(:acuant_assure_id_username)
    config.add(:acuant_attempt_window_in_minutes, type: :integer)
    config.add(:acuant_facial_match_license_key)
    config.add(:acuant_facial_match_url, type: :uri)
    config.add(:acuant_maintenance_window_finish)
    config.add(:acuant_maintenance_window_start)
    config.add(:acuant_max_attempts, type: :integer)
    config.add(:acuant_passlive_url, type: :uri)
    config.add(:acuant_sdk_initialization_creds)
    config.add(:acuant_sdk_initialization_endpoint, type: :uri)
    config.add(:acuant_timeout, type: :integer)
    config.add(:add_email_link_valid_for_hours, type: :integer)
    config.add(:address_proof_result_lambda_token)
    config.add(:allow_piv_cac_required, type: :boolean)
    config.add(:asset_host)
    config.add(:async_wait_timeout_seconds, type: :integer)
    config.add(:attribute_cost)
    config.add(:attribute_encryption_key)
    config.add(:attribute_encryption_key_queue, type: :json)
    # TODO: convert this
    config.add(:available_locales, type: :comma_separated_list)

    config.add(:aws_http_timeout, type: :integer)
    config.add(:aws_kms_key_id)
    config.add(:aws_kms_multi_region_enabled, type: :boolean)
    # TODO: Mitchell
    # config.add(:aws_kms_regions
    # config.add(:aws_logo_bucket
    # config.add(:aws_region
    # config.add(:backup_codes_as_only_2fa
    # config.add(:basic_auth_password
    # config.add(:basic_auth_user_name
    # config.add(:cac_proofing_enabled
    # config.add(:dashboard_api_token
    # config.add(:dashboard_url
    # config.add(:database_host
    # config.add(:database_name
    # config.add(:database_password
    # config.add(:database_pool_idp
    # config.add(:database_read_replica_host
    # config.add(:database_readonly_password
    # config.add(:database_readonly_username
    # config.add(:database_statement_timeout
    # config.add(:database_timeout
    # config.add(:database_username
    # config.add(:deleted_user_accounts_report_configs
    # config.add(:development
    # config.add(:disable_email_sending
    # config.add(:disallow_all_web_crawlers
    # config.add(:disallow_ial2_recovery
    # config.add(:doc_auth_enable_presigned_s3_urls
    # config.add(:doc_auth_extend_timeout_by_minutes
    # config.add(:doc_auth_vendor
    # config.add(:doc_capture_polling_enabled
    # config.add(:doc_capture_request_valid_for_minutes
    # config.add(:document_proof_result_lambda_token
    # config.add(:domain_name
    # config.add(:email_deletion_enabled
    # config.add(:email_from
    # config.add(:email_from_display_name
    # config.add(:enable_load_testing_mode
    # config.add(:enable_rate_limiting
    # config.add(:enable_test_routes
    # config.add(:enable_usps_verification
    # config.add(:event_disavowal_expiration_hours
    # config.add(:exception_recipients
    # config.add(:expired_letters_auth_token
    # config.add(:google_analytics_key
    # config.add(:google_analytics_timeout
    # config.add(:hmac_fingerprinter_key
    # config.add(:hmac_fingerprinter_key_queue
    # config.add(:ial2_recovery_request_valid_for_minutes
    # config.add(:identity_pki_disabled
    # config.add(:identity_pki_local_dev
    # config.add(:idv_attempt_window_in_hours
    # config.add(:idv_max_attempts
    # config.add(:idv_send_link_attempt_window_in_minutes
    # config.add(:idv_send_link_max_attempts
    # config.add(:in_person_proofing_enabled
    # config.add(:issuers_with_email_nameid_format
    # config.add(:job_run_healthchecks_enabled
    # config.add(:lexisnexis_account_id
    # config.add(:lexisnexis_base_url
    # config.add(:lexisnexis_instant_verify_workflow
    # config.add(:lexisnexis_password
    # config.add(:lexisnexis_phone_finder_workflow
    # config.add(:lexisnexis_request_mode
    # config.add(:lexisnexis_timeout
    # config.add(:lexisnexis_trueid_account_id
    # config.add(:lexisnexis_trueid_liveness_workflow
    # config.add(:lexisnexis_trueid_noliveness_workflow
    #
    # TODO: Hooper
    # config.add(:lexisnexis_trueid_password
    # config.add(:lexisnexis_trueid_username
    # config.add(:lexisnexis_username
    # config.add(:liveness_checking_enabled
    # config.add(:lockout_period_in_minutes
    # config.add(:log_to_stdout
    # config.add(:login_with_piv_cac
    # config.add(:logins_per_email_and_ip_bantime
    # config.add(:logins_per_email_and_ip_limit
    # config.add(:logins_per_email_and_ip_period
    # config.add(:logins_per_ip_limit
    # config.add(:logins_per_ip_period
    # config.add(:logins_per_ip_track_only_mode
    # config.add(:logo_upload_enabled
    # config.add(:mailer_domain_name
    # config.add(:max_auth_apps_per_account
    # config.add(:max_emails_per_account
    # config.add(:max_mail_events
    # config.add(:max_mail_events_window_in_days
    # config.add(:max_piv_cac_per_account
    # config.add(:min_password_score
    # config.add(:mx_timeout
    # config.add(:newrelic_browser_app_id
    # config.add(:newrelic_browser_key
    # config.add(:newrelic_license_key
    # config.add(:no_sp_campaigns_whitelist
    # config.add(:nonessential_email_banlist
    # config.add(:otp_delivery_blocklist_findtime
    # config.add(:otp_delivery_blocklist_maxretry
    # config.add(:otp_valid_for
    # config.add(:otps_per_ip_limit
    # config.add(:otps_per_ip_period
    # config.add(:otps_per_ip_track_only_mode
    # config.add(:outbound_connection_check_url
    # config.add(:participate_in_dap
    # config.add(:password_max_attempts
    # config.add(:password_pepper
    # config.add(:personal_key_retired
    # config.add(:pii_lock_timeout_in_minutes
    # config.add(:pinpoint_sms_application_id
    # config.add(:pinpoint_sms_credential_role_arn
    # config.add(:pinpoint_sms_longcode_pool
    # config.add(:pinpoint_sms_region
    # config.add(:pinpoint_sms_shortcode
    # config.add(:pinpoint_voice_credential_role_arn
    # config.add(:pinpoint_voice_longcode_pool
    # config.add(:pinpoint_voice_region
    # config.add(:piv_cac_service_url
    # config.add(:piv_cac_verify_token_secret
    # config.add(:piv_cac_verify_token_url
    # config.add(:poll_rate_for_verify_in_seconds
    # config.add(:production
    # config.add(:proofer_mock_fallback
    # config.add(:push_notifications_enabled
    # config.add(:rack_mini_profiler
    # config.add(:rack_timeout_service_timeout_seconds
    # config.add(:reauthn_window
    # config.add(:recaptcha_enabled_percent
    # config.add(:recaptcha_secret_key
    # config.add(:recaptcha_site_key
    # config.add(:recovery_code_length
    # config.add(:recurring_jobs_disabled_names
    # config.add(:redis_throttle_url
    # TODO: Zach
    # config.add(:redis_url
    # config.add(:reg_confirmed_email_max_attempts
    # config.add(:reg_confirmed_email_window_in_minutes
    # config.add(:reg_unconfirmed_email_max_attempts
    # config.add(:reg_unconfirmed_email_window_in_minutes
    # config.add(:remember_device_expiration_hours_aal_1
    # config.add(:remember_device_expiration_hours_aal_2
    # config.add(:remote_settings_certs_dir
    # config.add(:remote_settings_config_dir
    # config.add(:remote_settings_logos_dir
    # config.add(:remote_settings_whitelist
    # config.add(:report_timeout
    # config.add(:requests_per_ip_limit
    # config.add(:requests_per_ip_period
    # config.add(:requests_per_ip_track_only_mode
    # config.add(:reset_password_email_max_attempts
    # config.add(:reset_password_email_window_in_minutes
    # config.add(:resolution_proof_result_lambda_token
    # config.add(:s3_report_bucket_prefix
    # config.add(:s3_reports_enabled
    # config.add(:saml_endpoint_configs
    # config.add(:saml_secret_rotation_enabled
    # config.add(:scrypt_cost
    # config.add(:secret_key_base
    # config.add(:service_provider_request_ttl_hours
    # config.add(:session_check_delay
    # config.add(:session_check_frequency
    # config.add(:session_encryption_key
    # config.add(:session_timeout_in_minutes
    # config.add(:session_timeout_warning_seconds
    # config.add(:show_user_attribute_deprecation_warnings
    # config.add(:skip_encryption_allowed_list
    # config.add(:sp_context_needed_environment
    # config.add(:sp_handoff_bounce_max_seconds
    # config.add(:sps_over_quota_limit_notify_email_list
    # config.add(:telephony_adapter
    # config.add(:test
    # config.add(:unauthorized_scope_enabled
    # config.add(:use_dashboard_service_providers
    # config.add(:use_kms
    # config.add(:usps_confirmation_max_days
    # config.add(:usps_download_sftp_directory
    # config.add(:usps_download_sftp_host
    # config.add(:usps_download_sftp_password
    # config.add(:usps_download_sftp_timeout
    # config.add(:usps_download_sftp_username
    # config.add(:usps_download_token
    # config.add(:usps_ipp_password
    # config.add(:usps_ipp_root_url
    # config.add(:usps_ipp_sponsor_id
    # config.add(:usps_ipp_username
    # config.add(:usps_upload_enabled
    # config.add(:usps_upload_sftp_directory
    # config.add(:usps_upload_sftp_host
    # config.add(:usps_upload_sftp_password
    # config.add(:usps_upload_sftp_timeout
    # config.add(:usps_upload_sftp_username
    # config.add(:usps_upload_token
    final_env = config.add(:valid_authn_contexts, type: :json)

    @store = Struct.new('IdentityConfig', *final_env.keys, keyword_init: true).new(**final_env)
  end

  def self.config
    @@env
  end
end
