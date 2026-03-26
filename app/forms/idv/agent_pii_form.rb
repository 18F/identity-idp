# frozen_string_literal: true

module Idv
  class AgentPiiForm
    include ActiveModel::Model

    validate :state_id_xor_passport?
    validate :address_with_passport?
    validate :residential_address_valid?

    attr_reader :pii_from_agent

    def initialize(pii:)
      @pii_from_agent = pii
    end

    def submit
      doc_pii_response = DocPiiForm.new(pii: pii_from_doc).submit
      return doc_pii_response if !doc_pii_response.success?

      response = Idv::DocAuthFormResponse.new(
        success: valid?,
        errors: errors,
        extra: doc_pii_response.extra,
      )
      response.pii_from_doc = pii_from_agent
      response
    end

    private

    # Convert the PII into the format expected in DocPiiForm
    def pii_from_doc
      return @pii_from_doc if defined?(@pii_from_doc)

      result = pii_from_agent.deep_dup
      result[:document_type_received] = result.delete(:id_type)

      case result[:document_type_received]
      when *Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES
        state_id = result.delete(:state_id)
        raise ActionController::ParameterMissing.new(:state_id) if state_id.blank?

        result[:address1] = state_id[:address1]
        result[:address2] = state_id[:address2]
        result[:city] = state_id[:city]
        result[:state] = state_id[:state]
        result[:zipcode] = state_id[:zip_code]
        result[:state_id_jurisdiction] = state_id[:jurisdiction]
        result[:state_id_number] = state_id[:document_number]
        result[:state_id_expiration] = state_id[:expiration_date]

      when *Idp::Constants::DocumentTypes::SUPPORTED_PASSPORT_TYPES
        passport = result.delete(:passport)
        address = result.delete(:residential_address)
        raise ActionController::ParameterMissing.new(:passport) if passport.blank?
        raise ActionController::ParameterMissing.new(:residential_address) if address.blank?

        result[:passport_expiration] = passport[:expiration_date]
        result[:issuing_country_code] = passport[:issuing_country_code]
        result[:mrz] = passport[:mrz]
        result[:address1] = address[:address1]
        result[:address2] = address[:address2]
        result[:city] = address[:city]
        result[:state] = address[:state]
        result[:zipcode] = address[:zip_code]
      end

      @pii_from_doc = result
    end

    def state_id_xor_passport?
      if !(state_id_present? || passport_present?)
        errors.add(
          :base, :state_id_or_passport_blank,
          message: 'either state_id or passport must be present'
        )
      end
      if state_id_present? && passport_present?
        errors.add(
          :base, :state_id_and_passport,
          message: 'cannot include both state_id and passport'
        )
      end
    end

    def address_with_passport?
      if passport_present? && !residential_address_present?
        errors.add(
          :residential_address, :blank,
          message: 'residential address must be present with passport'
        )
      end
    end

    def residential_address_valid?
      return if !residential_address_present?

      address = pii_from_agent[:residential_address].dup
      address[:zipcode] = address.delete(:zip_code)
      form = AddressForm.new(address)
      return if form.valid?

      errors.merge!(form.errors)
    end

    def state_id_present?
      pii_from_agent[:state_id].present?
    end

    def passport_present?
      pii_from_agent[:passport].present?
    end

    def residential_address_present?
      pii_from_agent[:residential_address].present?
    end
  end
end
