require Rails.root.join('lib', 'config_validator.rb')

Figaro.require_keys(
  'attribute_cost',
  'attribute_encryption_key',
  'domain_name',
  'enable_identity_verification',
  'enable_rate_limiting',
  'enable_test_routes',
  'enable_usps_verification',
  'equifax_ssh_passphrase',
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
  'password_strength_enabled',
  'phone_proofing_vendor',
  'profile_proofing_vendor',
  'queue_health_check_dead_interval_seconds',
  'queue_health_check_frequency_seconds',
  'reauthn_window',
  'recovery_code_length',
  'redis_url',
  'requests_per_ip_limit',
  'requests_per_ip_period',
  'requests_per_ip_track_only_mode',
  'saml_passphrase',
  'scrypt_cost',
  'secret_key_base',
  'service_timeout',
  'session_encryption_key',
  'session_timeout_in_minutes',
  'state_id_proofing_vendor',
  'twilio_accounts',
  'twilio_record_voice',
  'use_kms',
  'valid_authn_contexts'
)

ConfigValidator.new.validate
