class SecurityEvent < ApplicationRecord
  AUTHORIZATION_FRAUD_DETECTED = 'https://schemas.login.gov/secevent/risc/event-type/authorization-fraud-detected'.freeze
  IDENTITY_FRAUD_DETECTED = 'https://schemas.login.gov/secevent/risc/event-type/identity-fraud-detected'.freeze

  EVENT_TYPES = [
    AUTHORIZATION_FRAUD_DETECTED,
    IDENTITY_FRAUD_DETECTED,
  ].freeze

  belongs_to :user
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: security_events
#
#  id          :bigint           not null, primary key
#  event_type  :string           not null
#  issuer      :string
#  jti         :string
#  occurred_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_security_events_on_jti_and_user_id_and_issuer  (jti,user_id,issuer) UNIQUE
#  index_security_events_on_user_id                     (user_id)
#
# rubocop:enable Layout/LineLength
