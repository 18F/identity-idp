class WebauthnConfiguration < ApplicationRecord
  belongs_to :user
  validates :name, presence: true
  validates :credential_id, presence: true
  validates :credential_public_key, presence: true

  def self.roaming_authenticators
    self.where(platform_authenticator: [nil, false])
  end

  def self.platform_authenticators
    self.where(platform_authenticator: true)
  end

  def mfa_enabled?
    true
  end

  def selection_presenters
    if platform_authenticator?
      [TwoFactorAuthentication::WebauthnPlatformSelectionPresenter.new(configuration: self)]
    else
      [TwoFactorAuthentication::WebauthnSelectionPresenter.new(configuration: self)]
    end
  end

  def friendly_name
    if platform_authenticator?
      :webauthn_platform
    else
      :webauthn
    end
  end

  def self.selection_presenters(set)
    if set.any?
      set.map(&:selection_presenters).flatten.uniq(&:class)
    else
      []
    end
  end
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: webauthn_configurations
#
#  id                     :bigint           not null, primary key
#  credential_public_key  :text             not null
#  name                   :string           not null
#  platform_authenticator :boolean
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  credential_id          :text             not null
#  user_id                :bigint           not null
#
# Indexes
#
#  index_webauthn_configurations_on_user_id  (user_id)
#
# rubocop:enable Layout/LineLength
