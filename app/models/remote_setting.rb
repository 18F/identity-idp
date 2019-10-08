class RemoteSetting < ApplicationRecord
  validates :url, format: {
    with:
      /\A(#{Figaro.env.remote_settings_whitelist}).+\z/,
  }
end
