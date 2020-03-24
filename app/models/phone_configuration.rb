class PhoneConfiguration < ApplicationRecord
  include EncryptableAttribute

  belongs_to :user, inverse_of: :phone_configurations
  validates :user_id, presence: true
  validates :encrypted_phone, presence: true

  encrypted_attribute(name: :phone)

  enum delivery_preference: { sms: 0, voice: 1 }

  def decorate
    PhoneConfigurationDecorator.new(self)
  end

  def formatted_phone
    Phonelib.parse(phone).international
  end

  def selection_presenters
    options = [TwoFactorAuthentication::SmsSelectionPresenter.new(self)]
    unless PhoneNumberCapabilities.new(phone).sms_only?
      options << TwoFactorAuthentication::VoiceSelectionPresenter.new(self)
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
