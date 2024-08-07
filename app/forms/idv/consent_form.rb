# frozen_string_literal: true

module Idv
  class ConsentForm
    include ActiveModel::Model

    attr_reader :idv_consent_given

    validates :idv_consent_given,
              acceptance: { message: proc { I18n.t('doc_auth.errors.consent_form') } }

    def initialize(idv_consent_given: false)
      @idv_consent_given = idv_consent_given
    end

    def submit(params)
      @idv_consent_given = params[:idv_consent_given] == '1'

      FormResponse.new(success: valid?, errors: errors)
    end
  end
end
