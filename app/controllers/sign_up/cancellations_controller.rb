module SignUp
  class CancellationsController < ApplicationController
    before_action :confirm_sign_up

    def new
      properties = ParseControllerFromReferer.new(request.referer).call
      analytics.track_event(Analytics::USER_REGISTRATION_CANCELLATION, properties)
      @presenter = CancellationPresenter.new(view_context: view_context)
    end

    private

    def confirm_sign_up
      redirect_to root_url unless session[:user_confirmation_token] || current_user
    end
  end
end
