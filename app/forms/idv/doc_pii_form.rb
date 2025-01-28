# frozen_string_literal: true

module Idv
  class DocPiiForm
    include ActiveModel::Model

    validate :name_valid?
    validate :dob_valid?
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

    attr_reader :first_name, :last_name, :dob, :address1, :state, :zipcode, :attention_with_barcode,
                :jurisdiction, :state_id_number, :state_id_expiration
    alias_method :attention_with_barcode?, :attention_with_barcode

    def initialize(pii:, attention_with_barcode: false)
      @pii_from_doc = pii
      @first_name = pii[:first_name]
      @last_name = pii[:last_name]
      @dob = pii[:dob]
      @address1 = pii[:address1]
      @state = pii[:state]
      @zipcode = pii[:zipcode]
      @jurisdiction = pii[:state_id_jurisdiction]
      @state_id_number = pii[:state_id_number]
      @state_id_expiration = pii[:state_id_expiration]
      @attention_with_barcode = attention_with_barcode
    end

    def submit
      response = Idv::DocAuthFormResponse.new(
        success: valid?,
        errors: errors,
        extra: {
          pii_like_keypaths: self.class.pii_like_keypaths,
          attention_with_barcode: attention_with_barcode?,
          id_issued_status: pii_from_doc[:state_id_issued].present? ? 'present' : 'missing',
          id_expiration_status: pii_from_doc[:state_id_expiration].present? ? 'present' : 'missing',
        },
      )
      response.pii_from_doc = pii_from_doc
      response
    end

    def self.pii_like_keypaths
      keypaths = [[:pii]]
      attrs = %i[name dob dob_min_age address1 state zipcode jurisdiction state_id_number]
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

    def state_id_expired?
      # temporary fix
      return if IdentityConfig.store.socure_docv_verification_data_test_mode &&
                state_id_expiration == Date.parse('2020-01-01')

      if state_id_expiration && DateParser.parse_legacy(state_id_expiration).past?
        errors.add(:state_id_expiration, generic_error, type: :state_id_expiration)
      end
    end

    def zipcode_valid?
      return if zipcode.is_a?(String) && zipcode.present?

      errors.add(:zipcode, generic_error, type: :zipcode)
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
