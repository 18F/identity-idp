module Users
    class MfaSelectionController < ApplicationController
      include UserAuthenticator
      include MfaSetupConcern

      def index
        @two_factor_options_form = TwoFactorOptionsForm.new(current_user)
        @presenter = two_factor_options_presenter
        analytics.track_event(Analytics::USER_REGISTRATION_2FA_SETUP_VISIT)
      end

      def create
        result = submit_form
        analytics.track_event(Analytics::USER_REGISTRATION_2FA_SETUP, result.to_h)

        if result.success?
          process_valid_form
        else
          @presenter = two_factor_options_presenter
          render :index
        end
      end

      private

      def submit_form
        @two_factor_options_form = TwoFactorOptionsForm.new(current_user)
        @two_factor_options_form.submit(two_factor_options_form_params)
      end

      def two_factor_options_presenter
        TwoFactorOptionsPresenter.new(
          user_agent: request.user_agent,
          user: current_user,
          aal3_required: service_provider_mfa_policy.aal3_required?,
          piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
        )
      end

      def process_valid_form
        user_session[:selected_mfa_options] = @two_factor_options_form.selection
        redirect_to confirmation_path(user_session[:selected_mfa_options].first)
      end

      def two_factor_options_form_params
        params.require(:two_factor_options_form).permit(:selection, selection: [])
      end
    end
  end
