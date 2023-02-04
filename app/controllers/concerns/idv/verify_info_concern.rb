module Idv
  module VerifyInfoConcern
    extend ActiveSupport::Concern

    def flow_session
      user_session['idv/doc_auth']
    end

    def confirm_pii_from_doc
      @pii = flow_session['pii_from_doc']
      return if @pii.present?
      redirect_to idv_doc_auth_url
    end
  end
end
