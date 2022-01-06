module OpenidConnect
  class LogoutController < ApplicationController
    include SecureHeadersConcern

    before_action :apply_secure_headers_override, only: [:index]

    def index
      @logout_form = OpenidConnectLogoutForm.new(params)

      result = @logout_form.submit

      analytics.track_event(Analytics::LOGOUT_INITIATED, result.to_h.except(:redirect_uri))

      if result.success? && (redirect_uri = result.extra[:redirect_uri])
        sign_out
        redirect_to redirect_uri unless params['prevent_logout_redirect'] == 'true'
      else
        render :error
      end
    end
  end
end
