require File.expand_path('../../../lib/figaro_yaml_validator', __FILE__)

Figaro.require_keys(
  'allow_third_party_auth',
  'domain_name',
  'enable_test_routes',
  'hmac_fingerprinter_key',
  'idp_sso_target_url',
  'keen_project_id',
  'keen_write_key',
  'logins_per_ip_limit',
  'logins_per_ip_period',
  'min_password_score',
  'otp_delivery_blocklist_bantime',
  'otp_delivery_blocklist_findtime',
  'otp_delivery_blocklist_maxretry',
  'otp_valid_for',
  'password_pepper',
  'password_strength_enabled',
  'queue_health_check_dead_interval_seconds',
  'queue_health_check_frequency_seconds',
  'reauthn_window',
  'recovery_code_length',
  'redis_url',
  'requests_per_ip_limit',
  'requests_per_ip_period',
  'saml_passphrase',
  'secret_key_base',
  'session_timeout_in_minutes',
  'support_email',
  'twilio_accounts',
  'use_kms',
  'valid_authn_contexts',
  'valid_service_providers'
)

FigaroYamlValidator.new.validate
