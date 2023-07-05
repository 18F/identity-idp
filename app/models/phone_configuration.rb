class PhoneConfiguration < ApplicationRecord
  include EncryptableAttribute

  belongs_to :user, inverse_of: :phone_configurations
  validates :encrypted_phone, presence: true

  encrypted_attribute(name: :phone)

  enum delivery_preference: { sms: 0, voice: 1 }

  def formatted_phone
    PhoneFormatter.format(phone)
  end

  def masked_phone
    PhoneFormatter.mask(phone)
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
