# frozen_string_literal: true

module Idv
  class DocPiiForm
    include ActiveModel::Model

    validate :name_valid?
    validate :dob_valid?
    validate :document_type_received_valid?

    attr_reader :first_name, :last_name, :dob, :attention_with_barcode,
                :jurisdiction, :state_id_number, :state_id_expiration, :document_type_received
    alias_method :attention_with_barcode?, :attention_with_barcode

    def initialize(pii:, attention_with_barcode: false)
      @pii_from_doc = pii
      @first_name = pii[:first_name]
      @last_name = pii[:last_name]
      @dob = pii[:dob]
      @document_type_received = pii[:document_type_received]
      @attention_with_barcode = attention_with_barcode
    end

    def submit
      response = Idv::DocAuthFormResponse.new(
        success: valid?,
        errors: errors,
        extra: {
          pii_like_keypaths: self.class.pii_like_keypaths(document_type: document_type_received),
          attention_with_barcode: attention_with_barcode?,
          document_type_received:,
          id_issued_status: pii_from_doc[:state_id_issued].present? ? 'present' : 'missing',
          id_expiration_status: pii_from_doc[:state_id_expiration].present? ? 'present' : 'missing',
          passport_issued_status: pii_from_doc[:passport_issued].present? ? 'present' : 'missing',
          passport_expiration_status: pii_from_doc[:passport_expiration].present? ?
            'present' : 'missing',
        },
      )
      response.pii_from_doc = pii_from_doc
      response
    end

    def self.pii_like_keypaths(document_type:)
      keypaths = [[:pii]]
      is_passport = document_type&.downcase
        &.include?(Idp::Constants::DocumentTypes::PASSPORT)
      document_attrs = is_passport ?
        PASSPORT_KEYPATH_ATTRS :
        STATE_ID_KEYPATH_ATTRS

      attrs = %i[name dob dob_min_age] + document_attrs

      attrs.each do |k|
        keypaths << [:errors, k]
        keypaths << [:error_details, k]
        keypaths << [:error_details, k, k]
      end
      keypaths
    end

    # Mutates the errors hash so callers (ImageUploadResponsePresenter) can render the right
    # consolidated messages. Values are i18n keys; the presenter resolves them.
    def self.present_error(existing_errors)
      return if existing_errors.blank?
      if existing_errors.any? { |k, _v| PII_ERROR_KEYS.include?(k) || ERROR_KEYS.include?(k) }
        existing_errors[:front] = ['doc_auth.errors.general.multiple_front_id_failures']
        existing_errors[:back] = ['doc_auth.errors.general.multiple_back_id_failures']
      end
      if existing_errors.many? { |k, _v| %i[name dob dob_min_age state].include?(k) }
        existing_errors.slice!(:front, :back)
        existing_errors[:pii] = ['doc_auth.errors.general.no_liveness']
      end
    end

    private

    PII_ERROR_KEYS = %i[name dob address1 state zipcode jurisdiction state_id_number
                        dob_min_age].freeze

    ERROR_KEYS = %i[state_id_verification].freeze

    # i18n keys emitted as error `message:` values. The presenter (ImageUploadResponsePresenter)
    # is the authoritative renderer; this form never calls I18n.t directly.
    NAME_ERROR_KEY = 'doc_auth.errors.alerts.full_name_check'
    DOB_ERROR_KEY = 'doc_auth.errors.alerts.birth_date_checks'
    # i18n-tasks-use t('doc_auth.errors.pii.birth_date_min_age')
    DOB_MIN_AGE_ERROR_KEY = 'doc_auth.errors.pii.birth_date_min_age'
    # i18n-tasks-use t('doc_auth.errors.alerts.address_check')
    ADDRESS_CHECK_ERROR_KEY = 'doc_auth.errors.alerts.address_check'
    GENERIC_ERROR_KEY = 'doc_auth.errors.general.no_liveness'

    STATE_ID_KEYPATH_ATTRS = %i[address1 state zipcode jurisdiction state_id_number].freeze
    PASSPORT_KEYPATH_ATTRS =
      %i[birth_place passport_issued issuing_country_code nationality_code mrz].freeze

    # DocPiiForm enforces a SUBSET of the canonical Pii::StateIdValidator rules — vendors don't
    # always extract issue_date, expiration_date, or city, so we only surface errors for fields
    # doc-capture actually contracts on.
    STATE_ID_DOC_CAPTURE_FIELDS = %i[address1 state jurisdiction document_number].freeze
    PASSPORT_DOC_CAPTURE_FIELDS = %i[mrz issuing_country_code].freeze

    # Maps canonical sub-form error keys back to DocPiiForm's pathway-specific keys.
    STATE_ID_ERROR_KEY_MAP = {
      document_number: :state_id_number,
    }.freeze

    PASSPORT_ERROR_KEY_MAP = {}.freeze

    attr_reader :pii_from_doc

    def name_valid?
      return if first_name.present? && last_name.present?

      errors.add(:name, NAME_ERROR_KEY, type: :name)
    end

    def dob_valid?
      if dob.blank?
        errors.add(:dob, DOB_ERROR_KEY, type: :dob)
        return
      end

      dob_date = DateParser.parse_legacy(dob)
      today = Time.zone.today
      age = today.year - dob_date.year - ((today.month > dob_date.month ||
        (today.month == dob_date.month && today.day >= dob_date.day)) ? 0 : 1)
      if age < IdentityConfig.store.idv_min_age_years
        errors.add(:dob_min_age, DOB_MIN_AGE_ERROR_KEY, type: :dob)
      end
    end

    def document_type_received_valid?
      case document_type_received
      when *Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES,
           Idp::Constants::DocumentTypes::MDL
        validate_state_id
      when *Idp::Constants::DocumentTypes::SUPPORTED_PASSPORT_TYPES
        validate_passport
      else
        errors.add(:no_document, GENERIC_ERROR_KEY, type: :no_document)
      end
    end

    # Order matters: the front-end's GeneralError component surfaces only the first non-front/back
    # error, and address1 (address_check) must lead when present to match the legacy DocPiiStateId
    # validation order. Run the sub-form (which yields address1 first) before zipcode/expiration.
    def validate_state_id
      state_id_form = Pii::StateIdForm.new(state_id: canonical_state_id)
      state_id_form.valid?

      merge_translated_errors(
        state_id_form.errors,
        allowed_fields: STATE_ID_DOC_CAPTURE_FIELDS,
        key_map: STATE_ID_ERROR_KEY_MAP,
      )

      validate_zipcode_format
      validate_state_id_expiration
    end

    def validate_passport
      validate_passport_expiration
      validate_passport_is_book

      passport_form = Pii::PassportForm.new(passport: canonical_passport)
      passport_form.valid?

      merge_translated_errors(
        passport_form.errors,
        allowed_fields: PASSPORT_DOC_CAPTURE_FIELDS,
        key_map: PASSPORT_ERROR_KEY_MAP,
      )
    end

    # Non-string zipcodes and zip+ext mismatches should fail with the legacy key. Pii::AddressForm
    # accepts a wider input shape and produces :zip_code keyed errors, but doc-capture's contract
    # is the legacy :zipcode key + this regex on a String value only.
    def validate_zipcode_format
      zipcode = pii_from_doc[:zipcode]
      return if zipcode.is_a?(String) && /^\d{5}(-\d{4})?$/.match?(zipcode)

      errors.add(:zipcode, GENERIC_ERROR_KEY, type: :zipcode)
    end

    # Doc capture treats state_id_expiration as optional and only flags it when present and past.
    # The socure_docv_verification_data_test_mode flag exempts 2020-01-01 (LG-15600).
    def validate_state_id_expiration
      exp = pii_from_doc[:state_id_expiration]
      return if exp.blank?
      return if IdentityConfig.store.socure_docv_verification_data_test_mode &&
                DateParser.parse_legacy(exp) == Date.parse('2020-01-01')
      return unless DateParser.parse_legacy(exp).past?

      errors.add(:state_id_expiration, GENERIC_ERROR_KEY, type: :state_id_expiration)
    end

    # Doc capture treats passport_expiration the same way: optional, flagged when present + past.
    def validate_passport_expiration
      exp = pii_from_doc[:passport_expiration]
      return if exp.blank?
      return unless DateParser.parse_legacy(exp).past?

      errors.add(:passport_expiration, GENERIC_ERROR_KEY, type: :passport_expiration)
    end

    def validate_passport_is_book
      return if pii_from_doc[:document_type_received] == 'passport'

      errors.add(:document_type_received, GENERIC_ERROR_KEY, type: :document_type_received)
    end

    def merge_translated_errors(sub_form_errors, allowed_fields:, key_map:)
      sub_form_errors.each do |error|
        next unless allowed_fields.include?(error.attribute)

        translated_key = key_map.fetch(error.attribute, error.attribute)
        message = address_error_message_for(translated_key)
        next if errors.added?(translated_key, message)

        errors.add(translated_key, message, type: error.type)
      end
    end

    def address_error_message_for(key)
      key == :address1 ? ADDRESS_CHECK_ERROR_KEY : GENERIC_ERROR_KEY
    end

    def canonical_state_id
      {
        document_number: pii_from_doc[:state_id_number],
        jurisdiction: pii_from_doc[:state_id_jurisdiction],
        expiration_date: pii_from_doc[:state_id_expiration],
        issue_date: pii_from_doc[:state_id_issued],
        address1: pii_from_doc[:address1],
        address2: pii_from_doc[:address2],
        city: pii_from_doc[:city],
        state: pii_from_doc[:state],
        zip_code: pii_from_doc[:zipcode],
      }
    end

    def canonical_passport
      {
        expiration_date: pii_from_doc[:passport_expiration],
        issue_date: pii_from_doc[:passport_issued],
        mrz: pii_from_doc[:mrz],
        issuing_country_code: pii_from_doc[:issuing_country_code],
      }
    end
  end
end
