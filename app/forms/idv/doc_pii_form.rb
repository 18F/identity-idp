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
      error_count = [name_error, dob_error].count(&:present?)

      return {} if error_count.zero?
      return { pii: multiple_errors_message } if error_count > 1
      { pii: name_error || dob_error || state_id_error }
    end

    def multiple_errors_message
      I18n.t('doc_auth.errors.lexis_nexis.general_error_no_liveness')
    end

    def name_error
      if errors.include?(:first_name) || errors.include?(:last_name)
        return I18n.t('doc_auth.errors.lexis_nexis.full_name_check')
      end
      nil
    end

    def dob_error
      return I18n.t('doc_auth.errors.lexis_nexis.birth_date_checks') if errors.include?(:dob)
      nil
    end
  end
end
