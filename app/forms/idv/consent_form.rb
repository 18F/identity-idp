module Idv
  class ConsentForm
    include ActiveModel::Model
    include FormConsentValidator

    def submit(params)
      ial2_consent_given = params[:ial2_consent_given]

      self.ial2_consent_given = ial2_consent_given

      FormResponse.new(success: valid?, errors: errors.messages)
    end
  end
end
