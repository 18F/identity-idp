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
      FormResponse.new(
        success: valid?,
        errors: errors.messages,
      )
    end

    private

    def validate_pii
      if error_count > 1
        errors.add(:pii, generic_error)
      elsif !name_valid?
        errors.add(:pii, name_error)
      elsif !dob_valid?
        errors.add(:pii, dob_error)
      elsif !state_valid?
        errors.add(:pii, generic_error)
      end
    end

    def name_valid?
      first_name.present? && last_name.present?
    end

    def dob_valid?
      dob.present?
    end

    def state_valid?
      state.present? && state.length == 2
    end

    def error_count
      [name_valid?, dob_valid?, state_valid?].count(&:blank?)
    end

    def generic_error
      I18n.t('doc_auth.errors.lexis_nexis.general_error_no_liveness')
    end

    def name_error
      I18n.t('doc_auth.errors.lexis_nexis.full_name_check')
    end

    def dob_error
      I18n.t('doc_auth.errors.lexis_nexis.birth_date_checks')
    end
  end
end
