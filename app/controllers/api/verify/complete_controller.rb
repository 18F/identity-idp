module Api
  module Verify
    class CompleteController < Api::BaseController
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
          render json: { personal_key: personal_key,
                         profile_pending: result.extra[:profile_pending] },
                 status: :ok
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
    end
  end
end
