# frozen_string_literal: true

module Api
  module Internal
    module TwoFactorAuthentication
      class WebauthnController < ApplicationController
        include CsrfTokenConcern
        include ReauthenticationRequiredConcern
        include MfaDeletionConcern

        before_action :render_unauthorized, unless: :recently_authenticated_2fa?

        after_action :add_csrf_token_header_to_response

        respond_to :json

        def update
          result = ::TwoFactorAuthentication::WebauthnUpdateForm.new(
            user: current_user,
            configuration_id: params[:id],
          ).submit(name: params[:name])

          analytics.webauthn_update_name_submitted(**result)

          if result.success?
            render json: { success: true }
          else
            render json: { success: false, error: result.first_error_message }, status: :bad_request
          end
        end

        def destroy
          form = ::TwoFactorAuthentication::WebauthnDeleteForm.new(
            user: current_user,
            configuration_id: params[:id],
          )
          result = form.submit

          analytics.webauthn_delete_submitted(**result)

          if result.success?
            handle_successful_mfa_deletion(event_type: form.event_type)
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
