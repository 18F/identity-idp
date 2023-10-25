# frozen_string_literal: true

module Idv
  class MailOnlyWarningController < ApplicationController
    include IdvSession
    include StepIndicatorConcern

    before_action :confirm_two_factor_authenticated

    def show
      analytics.idv_mail_only_warning_visited(analytics_id: 'Doc Auth')
      if defined?(idv_session)
        idv_session.mail_only_warning_shown = true
      end
      render :show, locals: { current_sp:, exit_url: }
    end

    def exit_url
      current_sp&.return_to_sp_url || account_path
    end
  end
end
