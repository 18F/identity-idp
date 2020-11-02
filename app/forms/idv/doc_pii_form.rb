module Idv
  class DocPiiForm
    include ActiveModel::Model

    validates_presence_of :first_name
    validates_presence_of :last_name
    validates_presence_of :dob

    attr_reader :first_name, :last_name, :dob

    def initialize(pii)
      @first_name = pii[:first_name]
      @last_name = pii[:last_name]
      @dob = pii[:dob]
    end

    def submit
      FormResponse.new(
        success: valid?,
        errors: error_hash,
        extra: { original_errors: errors },
      )
    end

    private

    def error_hash
      if name_error.present? && dob_error.present?
        { pii: multiple_errors_message }
      elsif name_error.present? || dob_error.present?
        { pii: name_error || dob_error }
      else
        {}
      end
    end

    def multiple_errors_message
      I18n.t('doc_auth.errors.lexis_nexis.general_error_no_liveness')
    end

    def name_error
      if errors.include?(:first_name) || errors.include?(:last_name)
        I18n.t('doc_auth.errors.lexis_nexis.full_name_check')
      end
    end

    def dob_error
      I18n.t('doc_auth.errors.lexis_nexis.birth_date_checks') if errors.include?(:dob)
    end
  end
end
