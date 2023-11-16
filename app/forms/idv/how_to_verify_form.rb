module Idv
  class HowToVerifyForm
    include ActiveModel::Model

    REMOTE = 'remote'.freeze
    IPP = 'ipp'.freeze

    attr_reader :selection

    validates :selection,
      presence: { message: proc { I18n.t('errors.doc_auth.how_to_verify_form') } }

    def initialize(selection: nil)
      @selection = selection
    end

    def submit(params)
      @selection = params[:selection]

      FormResponse.new(success: valid?, errors: errors)
    end
  end
end
