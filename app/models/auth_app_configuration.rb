# == Schema Information
#
# Table name: auth_app_configurations
#
#  id                       :bigint           not null, primary key
#  encrypted_otp_secret_key :string           not null
#  name                     :string           not null
#  totp_timestamp           :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  user_id                  :integer          not null
#
# Indexes
#
#  index_auth_app_configurations_on_user_id_and_created_at  (user_id,created_at) UNIQUE
#  index_auth_app_configurations_on_user_id_and_name        (user_id,name) UNIQUE
#
class AuthAppConfiguration < ApplicationRecord
  include EncryptableAttribute

  encrypted_attribute(name: :otp_secret_key)

  belongs_to :user

  validates :name, presence: true

  def mfa_enabled?
    otp_secret_key.present?
  end

  def selection_presenters
    if mfa_enabled?
      [TwoFactorAuthentication::AuthAppSelectionPresenter.new(configuration: self)]
    else
      []
    end
  end

  def friendly_name
    :auth_app
  end

  def self.selection_presenters(set)
    if set.any?
      set.first.selection_presenters
    else
      []
    end
  end
end
