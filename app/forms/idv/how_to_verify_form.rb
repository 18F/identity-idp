module Idv
  class HowToVerifyForm
    include ActiveModel::Model

    attr_reader :selection

    validates :selection, inclusion: {
      in: Idv::HowToVerifyController::VERIFICATION_OPTIONS,
      message: proc { I18n.t('errors.doc_auth.how_to_verify_form') }
    }

    def initialize(selection: nil)
      @selection = selection
    end

    def submit(params)
      @selection = params[:selection]

      FormResponse.new(success: valid?, errors: errors)
    end
  end
end
