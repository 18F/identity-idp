module Api
  module Internal
    module TwoFactorAuthentication
      class AuthAppController < ApplicationController
        include CsrfTokenConcern
        include ReauthenticationRequiredConcern

        before_action :render_unauthorized, unless: :recently_authenticated_2fa?

        after_action :add_csrf_token_header_to_response

        respond_to :json

        def update
          result = ::TwoFactorAuthentication::AuthAppUpdateForm.new(
            user: current_user,
            configuration_id: params[:id],
          ).submit(name: params[:name])

          analytics.auth_app_update_name_submitted(**result.to_h)

          if result.success?
            render json: { success: true }
          else
            render json: { success: false, error: result.first_error_message }, status: :bad_request
          end
        end

        def destroy
          result = ::TwoFactorAuthentication::AuthAppDeleteForm.new(
            user: current_user,
            configuration_id: params[:id],
          ).submit

          analytics.auth_app_delete_submitted(**result.to_h)

          if result.success?
            create_user_event(:authenticator_disabled)
            revoke_remember_device(current_user)
            event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
            PushNotification::HttpPush.deliver(event)
            render json: { success: true }
          else
            render json: { success: false, error: result.first_error_message }, status: :bad_request
          end
        end

        private

        def render_unauthorized
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end
