module Idv
  class SsnController < ApplicationController
    #    include IdvSession
    include VerifyInfoConcern

    before_action :render_404_if_ssn_controller_disabled
    before_action :confirm_two_factor_authenticated

    private

    def render_404_if_ssn_controller_disabled
      render_not_found unless IdentityConfig.store.doc_auth_ssn_controller_enabled
    end
  end
end
