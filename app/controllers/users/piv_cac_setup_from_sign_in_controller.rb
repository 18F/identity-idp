# frozen_string_literal: true

module Users
  class PivCacSetupFromSignInController < ApplicationController
    include PivCacConcern
    include ReauthenticationRequiredConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_recently_authenticated_2fa
    before_action :set_piv_cac_setup_csp_form_action_uris, only: :prompt

    def prompt
      analytics.piv_cac_setup_visited(in_account_creation_flow: false)
    end

    def decline
      session.delete(:needs_to_setup_piv_cac_after_sign_in)
      redirect_to after_sign_in_path_for(current_user)
    end
  end
end
