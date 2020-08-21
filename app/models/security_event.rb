class SecurityEvent < ApplicationRecord
  AUTHORIZATION_FRAUD_DETECTED = 'https://schemas.login.gov/secevent/risc/event-type/authorization-fraud-detected'.freeze
  IDENTITY_FRAUD_DETECTED = 'https://schemas.login.gov/secevent/risc/event-type/identity-fraud-detected'.freeze

  EVENT_TYPES = [
    AUTHORIZATION_FRAUD_DETECTED,
    IDENTITY_FRAUD_DETECTED,
  ].freeze

  belongs_to :user
end
