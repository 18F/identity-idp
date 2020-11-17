class RemoteSetting < ApplicationRecord
  validates :url, format: {
    with:
      /\A(#{AppConfig.env.remote_settings_whitelist}).+\z/,
  }
end
