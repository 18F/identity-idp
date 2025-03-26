# frozen_string_literal: true

module Idv
  class DocPiiForm
    include ActiveModel::Model

    validate :name_valid?
    validate :dob_valid?
    validate :state_id_or_passport

    attr_reader :first_name, :last_name, :dob, :state_id_type, :attention_with_barcode
    alias_method :attention_with_barcode?, :attention_with_barcode

    def initialize(pii:, attention_with_barcode: false)
      @pii_from_doc = pii
      @first_name = pii[:first_name]
      @last_name = pii[:last_name]
      @dob = pii[:dob]
      @state_id_type = pii[:state_id_type]
      @attention_with_barcode = attention_with_barcode
    end

    def submit
      response = Idv::DocAuthFormResponse.new(
        success: valid?,
        errors: errors,
        extra: {
          pii_like_keypaths: self.class.pii_like_keypaths(document_type: state_id_type),
          attention_with_barcode: attention_with_barcode?,
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

    def self.pii_like_keypaths(document_type: nil)
      keypaths = [[:pii]]
      document_attrs = document_type&.downcase == 'passport' ?
        DocPiiPassport.pii_like_keypaths :
        DocPiiStateId.pii_like_keypaths

      attrs = %i[name dob dob_min_age] + document_attrs

      attrs.each do |k|
        keypaths << [:errors, k]
        keypaths << [:error_details, k]
        keypaths << [:error_details, k, k]
      end
      keypaths
    end

    # Modifies the errors object, used in image_upload_response_presenter to customize
    # error messages for rendering  pii errors
    #
    # errors: The DocPiiForm errors object
    def self.present_error(existing_errors)
      return if existing_errors.blank?
      if existing_errors.any? { |k, _v| PII_ERROR_KEYS.include?(k) }
        existing_errors[:front] = [I18n.t('doc_auth.errors.general.multiple_front_id_failures')]
        existing_errors[:back] = [I18n.t('doc_auth.errors.general.multiple_back_id_failures')]
      end
      if existing_errors.many? { |k, _v| %i[name dob dob_min_age state].include?(k) }
        existing_errors.slice!(:front, :back)
        existing_errors[:pii] = [I18n.t('doc_auth.errors.general.no_liveness')]
      end
    end

    private

    PII_ERROR_KEYS = %i[name dob address1 state zipcode jurisdiction state_id_number
                        dob_min_age].freeze

    attr_reader :pii_from_doc

    def name_valid?
      return if first_name.present? && last_name.present?

      errors.add(:name, name_error, type: :name)
    end

    def dob_valid?
      if dob.blank?
        errors.add(:dob, dob_error, type: :dob)
        return
      end

      dob_date = DateParser.parse_legacy(dob)
      today = Time.zone.today
      age = today.year - dob_date.year - ((today.month > dob_date.month ||
        (today.month == dob_date.month && today.day >= dob_date.day)) ? 0 : 1)
      if age < IdentityConfig.store.idv_min_age_years
        errors.add(:dob_min_age, dob_min_age_error, type: :dob)
      end
    end

    def state_id_or_passport
      case state_id_type
      when 'drivers_license', 'state_id_card'
        state_id_validation = DocPiiStateId.new(pii: pii_from_doc)
        state_id_validation.valid? || errors.merge!(state_id_validation.errors)
      when 'passport'
        passport_validation = DocPiiPassport.new(pii: pii_from_doc)
        passport_validation.valid? || errors.merge!(passport_validation.errors)
      else
        errors.add(:no_document, generic_error, type: :no_document)
      end
    end

    def generic_error
      I18n.t('doc_auth.errors.general.no_liveness')
    end

    def name_error
      I18n.t('doc_auth.errors.alerts.full_name_check')
    end

    def dob_error
      I18n.t('doc_auth.errors.alerts.birth_date_checks')
    end

    def dob_min_age_error
      I18n.t('doc_auth.errors.pii.birth_date_min_age')
    end
  end
end
