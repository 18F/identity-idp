# frozen_string_literal: true

module Api
  module Internal
    module TwoFactorAuthentication
      class PivCacController < ApplicationController
        include CsrfTokenConcern
        include ReauthenticationRequiredConcern
        include PivCacConcern

        before_action :render_unauthorized, unless: :recently_authenticated_2fa?

        after_action :add_csrf_token_header_to_response

        respond_to :json

        def update
          result = ::TwoFactorAuthentication::PivCacUpdateForm.new(
            user: current_user,
            configuration_id: params[:id],
          ).submit(name: params[:name])

          analytics.piv_cac_update_name_submitted(**result)

          if result.success?
            render json: { success: true }
          else
            render json: { success: false, error: result.first_error_message }, status: :bad_request
          end
        end

        def destroy
          result = ::TwoFactorAuthentication::PivCacDeleteForm.new(
            user: current_user,
            configuration_id: params[:id],
          ).submit

          analytics.piv_cac_delete_submitted(**result)

          if result.success?
            create_user_event(:piv_cac_disabled)
            revoke_remember_device(current_user)
            deliver_push_notification
            clear_piv_cac_information
            render json: { success: true }
          else
            render json: { success: false, error: result.first_error_message }, status: :bad_request
          end
        end

        private

        def deliver_push_notification
          event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
          PushNotification::HttpPush.deliver(event)
        end

        def render_unauthorized
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end
