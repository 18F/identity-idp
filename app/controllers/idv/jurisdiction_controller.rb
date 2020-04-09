module Idv
  class JurisdictionController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def failure
      presenter = Idv::JurisdictionFailurePresenter.new(
        reason: params[:reason],
        jurisdiction: idv_session.selected_jurisdiction,
        view_context: view_context,
      )
      render_full_width('shared/_failure', locals: { presenter: presenter })
    end
  end
end
