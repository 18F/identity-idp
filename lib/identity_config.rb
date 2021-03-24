class IdentityConfig
  class << self
    attr_reader :store
  end

  CONVERTERS = {
    uri: proc { |value| URI(value) },
    string: proc { |value| value.to_s },
    comma_separated_string_list: proc do |value|
      value.split(',')
    end,
    integer: proc do |value|
      Integer(value)
    end,
    json: proc do |value, options: {}|
      JSON.parse(value, symbolize_names: options[:symbolize_names])
    end,
    boolean: proc do |value|
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
  def add(key, type: :string, is_sensitive: false, options: {})
    value = @read_env[key]
    raise "#{key} is required but is not present" if value.nil?
    converted_value = CONVERTERS.fetch(type).call(value, options: options)
    raise "#{key} is required but is not present" if converted_value.nil?

    @written_env[key] = converted_value
    @written_env
  end

  def self.build_settings(config_map)
    config = IdentityConfig.new(config_map)
    binding.pry

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
    config.add(:available_locales, type: :comma_separated_string_list)
    config.add(:aws_http_timeout, type: :integer)
    config.add(:aws_http_retry_limit, type: :integer)
    config.add(:aws_http_retry_max_delay, type: :integer)
    config.add(:aws_kms_key_id)
    config.add(:aws_kms_multi_region_enabled, type: :boolean)
    # TODO: Mitchell
    config.add(:aws_kms_regions, type: :json)
    config.add(:aws_logo_bucket)
    config.add(:aws_region)
    config.add(:backup_codes_as_only_2fa, type: :boolean)
    config.add(:basic_auth_password)
    config.add(:basic_auth_user_name)
    # TODO: remove? does not appear to be used
    config.add(:cac_proofing_enabled, type: :boolean)
    config.add(:dashboard_api_token)
    config.add(:dashboard_url)
    config.add(:database_host)
    config.add(:database_name)
    config.add(:database_password)
    config.add(:database_pool_idp, type: :integer)
    config.add(:database_read_replica_host)
    config.add(:database_readonly_password)
    config.add(:database_readonly_username)
    config.add(:database_statement_timeout, type: :integer)
    config.add(:database_timeout, type: :integer)
    config.add(:database_username)
    config.add(:deleted_user_accounts_report_configs, type: :json)
    config.add(:disable_email_sending, type: :boolean)
    config.add(:disallow_all_web_crawlers, type: :boolean)
    config.add(:disallow_ial2_recovery, type: :boolean)
    config.add(:doc_auth_enable_presigned_s3_urls, type: :boolean)
    config.add(:doc_auth_extend_timeout_by_minutes, type: :integer)
    config.add(:doc_auth_vendor)
    config.add(:doc_capture_polling_enabled, type: :boolean)
    config.add(:doc_capture_request_valid_for_minutes, type: :integer)
    config.add(:document_proof_result_lambda_token)
    config.add(:domain_name)
    # TODO: remove? does not appear to be used
    config.add(:email_deletion_enabled, type: :boolean)
    config.add(:email_from)
    config.add(:email_from_display_name)
    config.add(:enable_load_testing_mode, type: :boolean)
    config.add(:enable_rate_limiting, type: :boolean)
    config.add(:enable_test_routes, type: :boolean)
    config.add(:enable_usps_verification, type: :boolean)
    config.add(:event_disavowal_expiration_hours, type: :integer)
    config.add(:exception_recipients, type: :comma_separated_string_list)
    config.add(:expired_letters_auth_token)
    config.add(:hmac_fingerprinter_key)
    config.add(:hmac_fingerprinter_key_queue, type: :json)
    config.add(:ial2_recovery_request_valid_for_minutes, type: :integer)
    config.add(:identity_pki_disabled, type: :boolean)
    config.add(:identity_pki_local_dev, type: :boolean)
    config.add(:idv_attempt_window_in_hours, type: :integer)
    config.add(:idv_max_attempts, type: :integer)
    config.add(:idv_send_link_attempt_window_in_minutes, type: :integer)
    config.add(:idv_send_link_max_attempts, type: :integer)
    config.add(:in_person_proofing_enabled, type: :boolean)
    config.add(:issuers_with_email_nameid_format, type: :comma_separated_string_list)
    config.add(:job_run_healthchecks_enabled, type: :boolean)
    config.add(:lexisnexis_account_id)
    config.add(:lexisnexis_base_url)
    config.add(:lexisnexis_instant_verify_workflow)
    config.add(:lexisnexis_password)
    config.add(:lexisnexis_phone_finder_workflow)
    config.add(:lexisnexis_request_mode)
    config.add(:lexisnexis_timeout, type: :integer)
    config.add(:lexisnexis_trueid_account_id)
    config.add(:lexisnexis_trueid_liveness_workflow)
    config.add(:lexisnexis_trueid_noliveness_workflow)
    #
    # TODO: Hooper
    config.add(:lexisnexis_trueid_password)
    config.add(:lexisnexis_trueid_username)
    config.add(:lexisnexis_username)
    config.add(:liveness_checking_enabled, type: :boolean)
    config.add(:lockout_period_in_minutes, type: :integer)
    config.add(:log_to_stdout, type: :boolean)
    config.add(:logins_per_email_and_ip_bantime, type: :integer)
    config.add(:logins_per_email_and_ip_limit, type: :integer)
    config.add(:logins_per_email_and_ip_period, type: :integer)
    config.add(:logins_per_ip_limit, type: :integer)
    config.add(:logins_per_ip_period, type: :integer)
    config.add(:logins_per_ip_track_only_mode, type: :boolean)
    config.add(:logo_upload_enabled, type: :boolean)
    config.add(:mailer_domain_name, type: :uri)
    config.add(:max_auth_apps_per_account, type: :integer)
    config.add(:max_emails_per_account, type: :integer)
    config.add(:max_mail_events, type: :integer)
    config.add(:max_mail_events_window_in_days, type: :integer)
    config.add(:max_piv_cac_per_account, type: :integer)
    config.add(:min_password_score, type: :integer)
    config.add(:mx_timeout, type: :integer)
    config.add(:newrelic_browser_app_id)
    config.add(:newrelic_browser_key)
    config.add(:newrelic_license_key)
    config.add(:no_sp_campaigns_whitelist, type: :json)
    config.add(:nonessential_email_banlist, type: :json)
    config.add(:otp_delivery_blocklist_findtime, type: :integer)
    config.add(:otp_delivery_blocklist_maxretry, type: :integer)
    config.add(:otp_valid_for, type: :integer)
    config.add(:otps_per_ip_limit, type: :integer)
    config.add(:otps_per_ip_period, type: :integer)
    config.add(:otps_per_ip_track_only_mode, type: :boolean)
    config.add(:outbound_connection_check_url, type: :uri)
    config.add(:participate_in_dap, type: :boolean)
    config.add(:password_max_attempts, type: :integer)
    config.add(:password_pepper)
    config.add(:personal_key_retired, type: :boolean)
    config.add(:pii_lock_timeout_in_minutes, type: :integer)
    config.add(:pinpoint_sms_application_id)
    config.add(:pinpoint_sms_credential_role_arn)
    config.add(:pinpoint_sms_longcode_pool, type: :json)
    config.add(:pinpoint_sms_region)
    config.add(:pinpoint_sms_shortcode)
    config.add(:pinpoint_voice_credential_role_arn)
    config.add(:pinpoint_voice_longcode_pool)
    config.add(:pinpoint_voice_region)
    config.add(:piv_cac_service_url, type: :uri)
    config.add(:piv_cac_verify_token_secret)
    config.add(:piv_cac_verify_token_url, type: :uri)
    config.add(:poll_rate_for_verify_in_seconds, type: :integer)
    config.add(:proofer_mock_fallback, type: :boolean)
    config.add(:push_notifications_enabled, type: :boolean)
    # TODO: This is a boolean, but currently values are 'on' and 'off'
    config.add(:rack_mini_profiler, type: :string)
    config.add(:rack_timeout_service_timeout_seconds, type: :integer)
    config.add(:reauthn_window, type: :integer)
    config.add(:recaptcha_enabled_percent, type: :integer)
    config.add(:recaptcha_secret_key)
    config.add(:recaptcha_site_key)
    config.add(:recovery_code_length, type: :integer)
    config.add(:recurring_jobs_disabled_names, type: :json)
    config.add(:redis_throttle_url, type: :uri)
    # TODO: Zach
    config.add(:redis_url, type: :uri)
    config.add(:reg_confirmed_email_max_attempts, type: :integer)
    config.add(:reg_confirmed_email_window_in_minutes, type: :integer)
    config.add(:reg_unconfirmed_email_max_attempts, type: :integer)
    config.add(:reg_unconfirmed_email_window_in_minutes, type: :integer)
    config.add(:remember_device_expiration_hours_aal_1, type: :integer)
    config.add(:remember_device_expiration_hours_aal_2, type: :integer)
    # config.add(:report_timeout, type: :integer) # not set anywhere, needs to be nillable
    config.add(:requests_per_ip_limit, type: :integer)
    config.add(:requests_per_ip_period, type: :integer)
    config.add(:requests_per_ip_track_only_mode, type: :boolean)
    config.add(:reset_password_email_max_attempts, type: :integer)
    config.add(:reset_password_email_window_in_minutes, type: :integer)
    config.add(:resolution_proof_result_lambda_token)
    config.add(:s3_report_bucket_prefix)
    config.add(:s3_reports_enabled, type: :boolean)
    config.add(:saml_endpoint_configs, type: :json, options: { symbolize_names: true })
    config.add(:saml_secret_rotation_enabled, type: :boolean)
    config.add(:scrypt_cost)
    config.add(:secret_key_base)
    config.add(:service_provider_request_ttl_hours, type: :integer)
    config.add(:session_check_delay, type: :integer)
    config.add(:session_check_frequency, type: :integer)
    config.add(:session_encryption_key)
    config.add(:session_timeout_in_minutes, type: :integer)
    config.add(:session_timeout_warning_seconds, type: :integer)
    config.add(:show_user_attribute_deprecation_warnings, type: :boolean)
    config.add(:skip_encryption_allowed_list, type: :json)
    config.add(:sp_context_needed_environment)
    config.add(:sp_handoff_bounce_max_seconds, type: :integer)
    config.add(:sps_over_quota_limit_notify_email_list, type: :json)
    config.add(:telephony_adapter)
    config.add(:unauthorized_scope_enabled, type: :boolean)
    config.add(:use_dashboard_service_providers, type: :boolean)
    config.add(:use_kms, type: :boolean)
    config.add(:usps_confirmation_max_days, type: :integer)
    config.add(:usps_download_sftp_directory)
    config.add(:usps_download_sftp_host)
    config.add(:usps_download_sftp_password)
    config.add(:usps_download_sftp_timeout, type: :integer)
    config.add(:usps_download_sftp_username)
    config.add(:usps_download_token)
    config.add(:usps_ipp_password)
    config.add(:usps_ipp_root_url, type: :uri)
    config.add(:usps_ipp_sponsor_id)
    config.add(:usps_ipp_username)
    config.add(:usps_upload_enabled, type: :boolean)
    config.add(:usps_upload_sftp_directory)
    config.add(:usps_upload_sftp_host)
    config.add(:usps_upload_sftp_password)
    config.add(:usps_upload_sftp_timeout, type: :integer)
    config.add(:usps_upload_sftp_username)
    config.add(:usps_upload_token)
    final_env = config.add(:valid_authn_contexts, type: :json)

    @store = Struct.new('IdentityConfig', *final_env.keys, keyword_init: true).new(**final_env)
  end

  def self.config
    @@env
  end
end
