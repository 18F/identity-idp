module Idv
  class DocPiiForm
    include ActiveModel::Model

    validate :validate_pii

    attr_reader :first_name, :last_name, :dob

    def initialize(pii)
      @first_name = pii[:first_name]
      @last_name = pii[:last_name]
      @dob = pii[:dob]
    end

    def submit
      FormResponse.new(
        success: valid?,
        errors: errors.messages,
      )
    end

    private

    def validate_pii
      if (first_name.blank? || last_name.blank?) && dob.blank?
        errors.add(:pii, multiple_errors_message)
      elsif dob.blank?
        errors.add(:pii, dob_error)
      elsif first_name.blank? || last_name.blank?
        errors.add(:pii, name_error)
      end
    end

    def multiple_errors_message
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
