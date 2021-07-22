module Idv
  class DocPiiForm
    include ActiveModel::Model

    validate :validate_pii

    attr_reader :first_name, :last_name, :dob, :state

    def initialize(pii)
      @first_name = pii[:first_name]
      @last_name = pii[:last_name]
      @dob = pii[:dob]
      @state = pii[:state]
    end

    def submit
      Idv::DocAuthFormResponse.new(
        success: valid?,
        errors: errors,
      )
    end

    private

    def validate_pii
      if error_count > 1
        errors.add(:pii, generic_error)
      elsif !name_valid?
        errors.add(:pii, name_error)
      elsif dob.blank?
        errors.add(:pii, dob_error)
      elsif !dob_meets_min_age?
        errors.add(:pii, dob_min_age_error)
      elsif !state_valid?
        errors.add(:pii, generic_error)
      end
    end

    def name_valid?
      first_name.present? && last_name.present?
    end

    def dob_valid?
      dob.present? && dob_meets_min_age?
    end

    def dob_meets_min_age?
      dob_date = DateParser.parse_legacy(dob)
      today = Time.zone.today
      age = today.year - dob_date.year - ((today.month > dob_date.month ||
        (today.month == dob_date.month && today.day >= dob_date.day)) ? 0 : 1)
      age >= IdentityConfig.store.idv_min_age_years
    end

    def state_valid?
      state.present? && state.length == 2
    end

    def error_count
      [name_valid?, dob_valid?, state_valid?].count(&:blank?)
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
