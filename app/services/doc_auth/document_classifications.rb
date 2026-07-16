# frozen_string_literal: true

module DocAuth::DocumentClassifications
  PASSPORT = 'Passport'
  PASSPORT_CARD = 'PassportCard'
  PASSPORT_CARD_SPACED = 'Passport Card'
  IDENTIFICATION_CARD = 'Identification Card'
  DRIVERS_LICENSE = 'Drivers License'

  ALL_CLASSIFICATIONS = [
    PASSPORT,
    PASSPORT_CARD,
    PASSPORT_CARD_SPACED,
    IDENTIFICATION_CARD,
    DRIVERS_LICENSE,
  ].freeze
  STATE_ID_CLASSIFICATIONS = [IDENTIFICATION_CARD, DRIVERS_LICENSE].freeze

  CLASSIFICATION_TO_DOCUMENT_TYPE = {
    PASSPORT => Idp::Constants::DocumentTypes::PASSPORT,
    PASSPORT_CARD => Idp::Constants::DocumentTypes::PASSPORT_CARD,
    PASSPORT_CARD_SPACED => Idp::Constants::DocumentTypes::PASSPORT_CARD,
    DRIVERS_LICENSE => Idp::Constants::DocumentTypes::DRIVERS_LICENSE,
    IDENTIFICATION_CARD => Idp::Constants::DocumentTypes::IDENTIFICATION_CARD,
  }.freeze

  STATE_ID_CLASSIFICATION_TO_DOCUMENT_TYPE = {
    DRIVERS_LICENSE => Idp::Constants::DocumentTypes::DRIVERS_LICENSE,
    IDENTIFICATION_CARD => Idp::Constants::DocumentTypes::IDENTIFICATION_CARD,
  }.freeze
end
