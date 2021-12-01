module Idv
  class ConsentForm
    include ActiveModel::Model

    validates :ial2_consent_given?,
              acceptance: { message: proc { I18n.t('errors.doc_auth.consent_form') } }

    def submit(params)
      @ial2_consent_given = params[:ial2_consent_given] == '1'

      FormResponse.new(success: valid?, errors: errors)
    end

    def ial2_consent_given?
      @ial2_consent_given
    end
  end
end
