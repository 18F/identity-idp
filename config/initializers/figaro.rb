require Rails.root.join('lib', 'config_validator.rb')

Figaro.require_keys(
  'attribute_cost',
  'attribute_encryption_key',
  'database_statement_timeout',
  'disallow_all_web_crawlers',
  'domain_name',
  'enable_rate_limiting',
  'enable_test_routes',
  'enable_usps_verification',
  'exception_recipients',
  'hmac_fingerprinter_key',
  'issuers_with_email_nameid_format',
  'logins_per_ip_limit',
  'logins_per_ip_period',
  'logins_per_ip_track_only_mode',
  'logins_per_email_and_ip_bantime',
  'logins_per_email_and_ip_limit',
  'logins_per_email_and_ip_period',
  'max_mail_events',
  'max_mail_events_window_in_days',
  'min_password_score',
  'mx_timeout',
  'otp_delivery_blocklist_findtime',
  'otp_delivery_blocklist_maxretry',
  'otp_valid_for',
  'password_max_attempts',
  'password_pepper',
  'programmable_sms_countries',
  'queue_health_check_dead_interval_seconds',
  'RACK_TIMEOUT_SERVICE_TIMEOUT',
  'reauthn_window',
  'recovery_code_length',
  'redis_url',
  'requests_per_ip_limit',
  'requests_per_ip_period',
  'requests_per_ip_track_only_mode',
  'remember_device_expiration_hours_aal_1',
  'remember_device_expiration_hours_aal_2',
  'saml_endpoint_configs',
  'scrypt_cost',
  'secret_key_base',
  'session_encryption_key',
  'session_timeout_in_minutes',
  'twilio_numbers',
  'twilio_sid',
  'twilio_auth_token',
  'twilio_record_voice',
  'twilio_messaging_service_sid',
  'twilio_timeout',
  'use_kms',
  'valid_authn_contexts',
)

ConfigValidator.new.validate
