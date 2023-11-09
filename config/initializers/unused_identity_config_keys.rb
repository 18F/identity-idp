if !IdentityConfig.unused_keys.empty?
  Rails.logger.warn({ name: 'unused_identity_config_keys', keys: IdentityConfig.unused_keys })
end
