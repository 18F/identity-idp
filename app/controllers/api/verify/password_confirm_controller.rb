module Api
  module Verify
    class PasswordConfirmController < BaseController
      self.required_step = 'password_confirm'

      def create
        result, personal_key = Api::ProfileCreationForm.new(
          password: verify_params[:password],
          jwt: verify_params[:user_bundle_token],
          user_session: user_session,
          service_provider: current_sp,
        ).submit

        if result.success?
          user = User.find_by(uuid: result.extra[:user_uuid])
          add_proofing_component(user)
          render json: {
            personal_key: personal_key,
            completion_url: completion_url(result),
          }
        else
          render json: { error: result.errors }, status: :bad_request
        end
      end

      private

      def verify_params
        params.permit(:password, :user_bundle_token)
      end

      def add_proofing_component(user)
        ProofingComponent.create_or_find_by(user: user).update(verified_at: Time.zone.now)
      end

      def completion_url(result)
        if result.extra[:profile_pending]
          idv_come_back_later_url
        elsif current_sp
          sign_up_completed_url
        else
          account_url
        end
      end
    end
  end
end
