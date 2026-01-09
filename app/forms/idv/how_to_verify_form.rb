# frozen_string_literal: true

module Idv
  class HowToVerifyForm
    include ActiveModel::Model

    REMOTE = 'remote'
    IPP = 'ipp'

    attr_reader :selection

    validates :selection, presence: {
      message: proc { I18n.t('doc_auth.errors.how_to_verify_form') },
    }
    validates :selection, inclusion: {
      in: [REMOTE, IPP],
      message: proc { I18n.t('doc_auth.errors.how_to_verify_form') },
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
