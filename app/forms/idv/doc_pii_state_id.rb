# frozen_string_literal: true

module Idv
  class DocPiiStateId
    include ActiveModel::Model

    validates_presence_of :address1, { message: proc {
                                                  I18n.t('doc_auth.errors.alerts.address_check')
                                                } }

    validate :zipcode_valid?
    validates :jurisdiction, :state, inclusion: { in: Idp::Constants::STATE_AND_TERRITORY_CODES,
                                                  message: proc {
                                                    I18n.t('doc_auth.errors.general.no_liveness')
                                                  } }

    validates_presence_of :state_id_number, { message: proc {
      I18n.t('doc_auth.errors.general.no_liveness')
    } }
    validate :state_id_expired?

    attr_reader :address1, :state, :zipcode, :attention_with_barcode, :jurisdiction,
                :state_id_number, :state_id_expiration
    alias_method :attention_with_barcode?, :attention_with_barcode

    def initialize(pii:)
      @pii_from_doc = pii
      @address1 = pii[:address1]
      @state = pii[:state]
      @zipcode = pii[:zipcode]
      @jurisdiction = pii[:state_id_jurisdiction]
      @state_id_number = pii[:state_id_number]
      @state_id_expiration = pii[:state_id_expiration]
      @attention_with_barcode = attention_with_barcode
    end

    def self.pii_like_keypaths
      %i[address1 state zipcode jurisdiction state_id_number]
    end

    private

    attr_reader :pii_from_doc

    def generic_error
      I18n.t('doc_auth.errors.general.no_liveness')
    end

    def state_id_expired?
      # temporary fix, tracked for removal in LG-15600
      return if IdentityConfig.store.socure_docv_verification_data_test_mode &&
                DateParser.parse_legacy(state_id_expiration) == Date.parse('2020-01-01')

      if state_id_expiration && DateParser.parse_legacy(state_id_expiration).past?
        errors.add(:state_id_expiration, generic_error, type: :state_id_expiration)
      end
    end

    def zipcode_valid?
      return if zipcode.is_a?(String) && zipcode.present?

      errors.add(:zipcode, generic_error, type: :zipcode)
    end
  end
end
