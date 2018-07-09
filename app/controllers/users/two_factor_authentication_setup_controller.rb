module Users
  class TwoFactorAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include Authorizable

    before_action :authenticate_user
    before_action :authorize_user

    def index
      @two_factor_options_form = TwoFactorOptionsForm.new(current_user)
      @presenter = two_factor_options_presenter
      analytics.track_event(Analytics::USER_REGISTRATION_2FA_SETUP_VISIT)
    end

    def create
      @two_factor_options_form = TwoFactorOptionsForm.new(current_user)
      result = @two_factor_options_form.submit(two_factor_options_form_params)
      analytics.track_event(Analytics::USER_REGISTRATION_2FA_SETUP, result.to_h)

      if result.success?
        process_valid_form
      else
        @presenter = two_factor_options_presenter
        render :index
      end
    end

    private

    def two_factor_options_presenter
      TwoFactorOptionsPresenter.new(current_user, current_sp)
    end

    delegate :two_factor_method_manager, to: :current_user

    def process_valid_form
      method_manager = two_factor_method_manager.configuration_manager(
        @two_factor_options_form.selection
      )
      redirect_to full_url(method_manager.setup_path)
    end

    def two_factor_options_form_params
      params.require(:two_factor_options_form).permit(:selection)
    end

    # This is ugly, but it's the only way to get regular rspec and Capybara
    # tests to pass since the options for url generation in controllers are
    # different than when including url_helpers in a non-controller class.
    def full_url(path)
      (root_url + path).
        split(%r{://}, 2).
        map { |part| part.gsub(%r{//+}, '/') }.
        join('://')
    end
  end
end
