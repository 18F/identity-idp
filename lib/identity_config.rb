class IdentityConfig
  class << self
    attr_reader :store
  end

  CONVERTERS = {
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
      when 'true', true
        true
      when 'false', false
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

  def add(key, type: :string, is_sensitive: false, options: {})
    value = @read_env[key]
    raise "#{key} is required but is not present" if value.nil?
    converted_value = CONVERTERS.fetch(type).call(value, options: options)
    raise "#{key} is required but is not present" if converted_value.nil?

    @written_env[key] = converted_value
    @written_env
  end

  def self.build_store(config_map)
    config = IdentityConfig.new(config_map)
    config.add(:aal_authn_context_enabled, type: :boolean)
    config.add(:aamva_cert_enabled, type: :boolean)
    config.add(:aamva_sp_banlist_issuers, type: :json)
    config.add(:aamva_verification_url)
    config.add(:account_reset_token_valid_for_days, type: :integer)
    config.add(:account_reset_wait_period_days, type: :integer)
    config.add(:acuant_assure_id_url)
    config.add(:acuant_attempt_window_in_minutes, type: :integer)
    config.add(:acuant_facial_match_url)
    config.add(:acuant_max_attempts, type: :integer)
    config.add(:acuant_passlive_url)
    config.add(:acuant_sdk_initialization_endpoint)
    config.add(:acuant_timeout, type: :integer)
    config.add(:add_email_link_valid_for_hours, type: :integer)
    config.add(:async_wait_timeout_seconds, type: :integer)
    config.add(:attribute_encryption_key_queue, type: :json)
    config.add(:aws_http_retry_limit, type: :integer)
    config.add(:aws_http_retry_max_delay, type: :integer)
    config.add(:aws_http_timeout, type: :integer)
    config.add(:aws_kms_multi_region_enabled, type: :boolean)
    config.add(:aws_kms_regions, type: :json)
    config.add(:backup_code_skip_symmetric_encryption, type: :boolean)
    config.add(:database_pool_idp, type: :integer)
    config.add(:database_statement_timeout, type: :integer)
    config.add(:database_timeout, type: :integer)
    config.add(:deleted_user_accounts_report_configs, type: :json)
    config.add(:disable_email_sending, type: :boolean)
    config.add(:disallow_all_web_crawlers, type: :boolean)
    config.add(:disallow_ial2_recovery, type: :boolean)
    config.add(:doc_auth_enable_presigned_s3_urls, type: :boolean)
    config.add(:doc_auth_extend_timeout_by_minutes, type: :integer)
    config.add(:doc_capture_polling_enabled, type: :boolean)
    config.add(:doc_capture_request_valid_for_minutes, type: :integer)
    config.add(:domain_name, type: :string)
    config.add(:enable_load_testing_mode, type: :boolean)
    config.add(:enable_rate_limiting, type: :boolean)
    config.add(:enable_test_routes, type: :boolean)
    config.add(:enable_usps_verification, type: :boolean)
    config.add(:event_disavowal_expiration_hours, type: :integer)
    config.add(:exception_recipients, type: :comma_separated_string_list)
    config.add(:hmac_fingerprinter_key_queue, type: :json)
    config.add(:ial2_recovery_request_valid_for_minutes, type: :integer)
    config.add(:ial2_step_indicator_enabled, type: :boolean)
    config.add(:identity_pki_disabled, type: :boolean)
    config.add(:identity_pki_local_dev, type: :boolean)
    config.add(:idv_attempt_window_in_hours, type: :integer)
    config.add(:idv_max_attempts, type: :integer)
    config.add(:idv_send_link_attempt_window_in_minutes, type: :integer)
    config.add(:idv_send_link_max_attempts, type: :integer)
    config.add(:issuers_with_email_nameid_format, type: :comma_separated_string_list)
    config.add(:job_run_healthchecks_enabled, type: :boolean)
    config.add(:lexisnexis_timeout, type: :integer)
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
    config.add(:mailer_domain_name)
    config.add(:max_auth_apps_per_account, type: :integer)
    config.add(:max_emails_per_account, type: :integer)
    config.add(:max_mail_events, type: :integer)
    config.add(:max_mail_events_window_in_days, type: :integer)
    config.add(:max_piv_cac_per_account, type: :integer)
    config.add(:min_password_score, type: :integer)
    config.add(:mx_timeout, type: :integer)
    config.add(:no_sp_campaigns_whitelist, type: :json)
    config.add(:otp_delivery_blocklist_findtime, type: :integer)
    config.add(:otps_per_ip_track_only_mode, type: :boolean)
    config.add(:nonessential_email_banlist, type: :json)
    config.add(:outbound_connection_check_url)
    config.add(:participate_in_dap, type: :boolean)
    config.add(:personal_key_retired, type: :boolean)
    config.add(:piv_cac_service_url)
    config.add(:piv_cac_verify_token_url)
    config.add(:phone_setups_per_ip_track_only_mode, type: :boolean)
    config.add(:proofer_mock_fallback, type: :boolean)
    config.add(:push_notifications_enabled, type: :boolean)
    config.add(:rack_mini_profiler, type: :boolean)
    config.add(:recurring_jobs_disabled_names, type: :json)
    config.add(:redis_throttle_url)
    config.add(:redis_url)
    config.add(:requests_per_ip_track_only_mode, type: :boolean)
    config.add(:risc_notifications_local_enabled, type: :boolean)
    config.add(:s3_reports_enabled, type: :boolean)
    config.add(:saml_endpoint_configs, type: :json, options: { symbolize_names: true })
    config.add(:saml_secret_rotation_enabled, type: :boolean)
    config.add(:show_user_attribute_deprecation_warnings, type: :boolean)
    config.add(:skip_encryption_allowed_list, type: :json)
    config.add(:sps_over_quota_limit_notify_email_list, type: :json)
    config.add(:unauthorized_scope_enabled, type: :boolean)
    config.add(:use_dashboard_service_providers, type: :boolean)
    config.add(:use_kms, type: :boolean)
    config.add(:usps_upload_enabled, type: :boolean)
    config.add(:valid_authn_contexts, type: :json)
    final_env = config.add(:usps_ipp_root_url)

    @store = RedactedStruct.new('IdentityConfig', *final_env.keys, keyword_init: true).
      new(**final_env)
  end
end
