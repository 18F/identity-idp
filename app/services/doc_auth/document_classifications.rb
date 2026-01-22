# frozen_string_literal: true

module DocAuth::DocumentClassifications
  PASSPORT = 'Passport'
  IDENTIFICATION_CARD = 'Identification Card'
  DRIVERS_LICENSE = 'Drivers License'
  DDP_IDENTIFICATION_CARD = 'IdentificationCard'

  ALL_CLASSIFICATIONS = [PASSPORT, IDENTIFICATION_CARD, DRIVERS_LICENSE,
                         DDP_IDENTIFICATION_CARD].freeze
  STATE_ID_CLASSIFICATIONS = [IDENTIFICATION_CARD, DRIVERS_LICENSE].freeze

  CLASSIFICATION_TO_DOCUMENT_TYPE = {
    PASSPORT => Idp::Constants::DocumentTypes::PASSPORT,
    DRIVERS_LICENSE => Idp::Constants::DocumentTypes::DRIVERS_LICENSE,
    IDENTIFICATION_CARD => Idp::Constants::DocumentTypes::IDENTIFICATION_CARD,
    DDP_IDENTIFICATION_CARD => Idp::Constants::DocumentTypes::IDENTIFICATION_CARD,
  }.freeze

  STATE_ID_CLASSIFICATION_TO_DOCUMENT_TYPE = {
    DRIVERS_LICENSE => Idp::Constants::DocumentTypes::DRIVERS_LICENSE,
    IDENTIFICATION_CARD => Idp::Constants::DocumentTypes::IDENTIFICATION_CARD,
    DDP_IDENTIFICATION_CARD => Idp::Constants::DocumentTypes::IDENTIFICATION_CARD,
  }.freeze
end
