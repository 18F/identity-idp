# frozen_string_literal: true

module Idv
  class DocPiiPassport
    include ActiveModel::Model

    validates :mrz,
              presence: { message: proc { I18n.t('doc_auth.errors.general.no_liveness') } }

    validates :issuing_country_code,
              inclusion: {
                in: 'USA', message: proc { I18n.t('doc_auth.errors.general.no_liveness') }
              }

    validate :passport_not_expired?
    validate :passport_book? # we don't support passport cards

    attr_reader :passport_expiration, :issuing_country_code, :mrz

    def initialize(pii:)
      @pii_from_doc = pii
      @passport_expiration = pii[:passport_expiration]
      @issuing_country_code = pii[:issuing_country_code]
      @mrz = pii[:mrz]
    end

    def self.pii_like_keypaths
      %i[birth_place passport_issued issuing_country_code nationality_code mrz]
    end

    private

    attr_reader :pii_from_doc

    def generic_error
      I18n.t('doc_auth.errors.general.no_liveness')
    end

    def passport_not_expired?
      return true unless passport_expiration && DateParser.parse_legacy(passport_expiration).past?

      errors.add(:passport_expiration, generic_error, type: :passport_expiration)
      false
    end

    def passport_book?
      return true if pii_from_doc[:id_doc_type] == 'passport'

      errors.add(:id_doc_type, generic_error, type: :id_doc_type)
      false
    end
  end
end
