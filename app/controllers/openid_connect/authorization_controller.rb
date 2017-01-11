module OpenidConnect
  class AuthorizationController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def index
      @authorize_form = OpenidConnectAuthorizeForm.new(params)

      success = @authorize_form.valid?
      analytics.track_event(Analytics::OPENID_CONNECT_REQUEST_AUTHORIZATION,
                            success: success,
                            client_id: @authorize_form.client_id,
                            errors: @authorize_form.errors.messages)

      render(success ? :index : :error)
    end

    def create
      @authorize_form = OpenidConnectAuthorizeForm.new(params)

      result = @authorize_form.submit(current_user, session.id)
      analytics.track_event(Analytics::OPENID_CONNECT_ALLOW, result.except(:redirect_uri))

      if (redirect_uri = result[:redirect_uri])
        redirect_to redirect_uri
      else
        render :error
      end
    end

    def destroy
      @authorize_form = OpenidConnectAuthorizeForm.new(params)
      analytics.track_event(Analytics::OPENID_CONNECT_DECLINE, client_id: @authorize_form.client_id)

      render nothing: true # TODO: should we try to redirect back with an error?
    end
  end
end
