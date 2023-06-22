module Idv
  class GpoOnlyWarningController < ApplicationController
    include IdvSession
    include StepIndicatorConcern

    before_action :confirm_two_factor_authenticated

    def show
      user_session.fetch('idv/doc_auth', {})[:skip_vendor_outage] = true
      render :show, locals: { current_sp:, exit_url:, welcome_url: }
    end

    def exit_url
      current_sp&.return_to_sp_url || account_path
    end

    def welcome_url
      if IdentityConfig.store.doc_auth_welcome_controller_enabled
        idv_welcome_url
      else
        idv_doc_auth_step_path(step: :welcome)
      end
    end
  end
end
