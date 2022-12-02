# == Schema Information
#
# Table name: phone_configurations
#
#  id                   :bigint           not null, primary key
#  confirmation_sent_at :datetime
#  confirmed_at         :datetime
#  delivery_preference  :integer          default("sms"), not null
#  encrypted_phone      :text             not null
#  made_default_at      :datetime
#  mfa_enabled          :boolean          default(TRUE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  user_id              :bigint           not null
#
# Indexes
#
#  index_phone_configurations_on_made_default_at  (user_id,made_default_at,created_at)
#
class PhoneConfiguration < ApplicationRecord
  include EncryptableAttribute

  belongs_to :user, inverse_of: :phone_configurations
  validates :encrypted_phone, presence: true

  encrypted_attribute(name: :phone)

  enum delivery_preference: { sms: 0, voice: 1 }

  def formatted_phone
    Phonelib.parse(phone).international
  end

  def masked_phone
    return '' if phone.blank?

    formatted = Phonelib.parse(phone).national
    formatted[0..-5].gsub(/\d/, '*') + formatted[-4..-1]
  end

  def selection_presenters
    options = []

    capabilities = PhoneNumberCapabilities.new(phone, phone_confirmed: !!confirmed_at?)

    if capabilities.supports_sms?
      options << TwoFactorAuthentication::SmsSelectionPresenter.new(configuration: self)
    end

    if capabilities.supports_voice?
      options << TwoFactorAuthentication::VoiceSelectionPresenter.new(configuration: self)
    end

    options
  end

  def friendly_name
    :phone
  end

  def self.selection_presenters(set)
    set.flat_map(&:selection_presenters)
  end
end
