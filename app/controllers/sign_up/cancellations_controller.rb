module SignUp
  class CancellationsController < ApplicationController
    before_action :ensure_in_setup

    def new
      properties = ParseControllerFromReferer.new(request.referer).call
      analytics.track_event(Analytics::USER_REGISTRATION_CANCELLATION, properties)
      @presenter = CancellationPresenter.new(view_context: view_context)
    end

    private

    def ensure_in_setup
      redirect_to root_url if !session[:user_confirmation_token] && two_factor_enabled
    end

    def two_factor_enabled
      current_user && MfaPolicy.new(current_user).two_factor_enabled?
    end
  end
end
