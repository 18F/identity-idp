module Idv
  class ConsentForm
    include ActiveModel::Model

    validates :idv_consent_given?,
              acceptance: { message: proc { I18n.t('errors.doc_auth.consent_form') } }

    def submit(params)
      @idv_consent_given = params[:idv_consent_given] == '1' || params[:ial2_consent_given] == '1'

      FormResponse.new(success: valid?, errors: errors)
    end

    def idv_consent_given?
      @idv_consent_given
    end
  end
end
