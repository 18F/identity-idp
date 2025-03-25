# frozen_string_literal: true

class PhoneConfiguration < ApplicationRecord
  self.ignored_columns += %w[confirmation_sent_at]
  self.ignored_columns += %w[confirmed_at]
  include EncryptableAttribute

  belongs_to :user, inverse_of: :phone_configurations
  validates :encrypted_phone, presence: true

  encrypted_attribute(name: :phone)

  enum :delivery_preference, { sms: 0, voice: 1 }

  def formatted_phone
    PhoneFormatter.format(phone)
  end

  def masked_phone
    PhoneFormatter.mask(phone)
  end

  def selection_presenters
    options = []

    if capabilities.supports_sms?
      options << TwoFactorAuthentication::SignInPhoneSelectionPresenter
        .new(user:, configuration: self, delivery_method: :sms)
    end

    if capabilities.supports_voice?
      options << TwoFactorAuthentication::SignInPhoneSelectionPresenter
        .new(user:, configuration: self, delivery_method: :voice)
    end

    options
  end

  def capabilities
    PhoneNumberCapabilities.new(phone, phone_confirmed: !!confirmed_at?)
  end

  def friendly_name
    :phone
  end

  def self.selection_presenters(set)
    set.flat_map(&:selection_presenters)
  end
end
