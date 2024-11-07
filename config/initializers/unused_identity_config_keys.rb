# frozen_string_literal: true

if Identity::Hostdata.config_builder.unused_keys.present?
  Rails.logger.warn(
    { name: 'unused_identity_config_keys',
      keys: Identity::Hostdata.config_builder.unused_keys }.to_json,
  )
end

Rails.logger.info(
  {
    name: 'config_version',
    **Identity::Hostdata.configuration_version,
  }.to_json
)
