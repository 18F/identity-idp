module Idv
  class JurisdictionController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_attempts_allowed
    before_action :confirm_idv_needed
    before_action :confirm_step_needed, only: %i[new create]
    before_action :set_jurisdiction_form, except: [:failure]

    def new
      analytics.track_event(Analytics::IDV_JURISDICTION_VISIT)
    end

    def create
      result = @jurisdiction_form.submit(jurisdiction_params)
      analytics.track_event(Analytics::IDV_JURISDICTION_FORM, result.to_h)
      idv_session.selected_jurisdiction = @jurisdiction_form.state

      if result.success?
        redirect_to idv_session_url
      elsif ial2_consent_missing?
        handle_missing_ial2_consent
      else
        # The only invalid result here is due to an unsupported jurisdiction
        # and if it is missing from the params, it will be stopped by
        # `strong_params`.
        redirect_to failure_url(:unsupported_jurisdiction)
      end
    end

    def failure
      presenter = Idv::JurisdictionFailurePresenter.new(
        reason: params[:reason],
        jurisdiction: idv_session.selected_jurisdiction,
        view_context: view_context,
      )
      render_full_width('shared/_failure', locals: { presenter: presenter })
    end

    def jurisdiction_params
      params.require(:jurisdiction).permit(*Idv::JurisdictionForm::ATTRIBUTES)
    end

    private

    def set_jurisdiction_form
      @jurisdiction_form ||= Idv::JurisdictionForm.new
    end

    def confirm_step_needed
      selected_jurisdiction = idv_session.selected_jurisdiction
      return unless Idv::FormJurisdictionValidator::SUPPORTED_JURISDICTIONS.
                    include? selected_jurisdiction

      redirect_to idv_session_url unless selected_jurisdiction.nil?
    end

    def ial2_consent_missing?
      !@jurisdiction_form.ial2_consent_given?
    end

    def handle_missing_ial2_consent
      idv_session.selected_jurisdiction = nil
      render :new
    end

    def failure_url(reason)
      idv_jurisdiction_failure_url(reason)
    end
  end
end
