if IdentityConfig.unused_keys.present?
  Rails.logger.warn({ name: 'unused_identity_config_keys', keys: IdentityConfig.unused_keys })
end
