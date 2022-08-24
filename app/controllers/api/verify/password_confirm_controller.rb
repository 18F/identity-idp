module Api
  module Verify
    class PasswordConfirmController < BaseController
      rescue_from UspsInPersonProofing::Exception::RequestEnrollException,
                  with: :handle_request_enroll_exception

      self.required_step = 'password_confirm'

      def create
        result, personal_key = form.submit

        if result.success?
          user = User.find_by(uuid: result.extra[:user_uuid])
          add_proofing_component(user)
          store_session_last_gpo_code(form.gpo_code)

          render json: {
            personal_key: personal_key,
            completion_url: completion_url(result, user),
          }
        else
          render_errors(result.errors)
        end
      end

      private

      def form
        @form ||= Api::ProfileCreationForm.new(
          password: verify_params[:password],
          jwt: verify_params[:user_bundle_token],
          user_session: user_session,
          service_provider: current_sp,
        )
      end

      def store_session_last_gpo_code(code)
        session[:last_gpo_confirmation_code] = code if code && FeatureManagement.reveal_gpo_code?
      end

      def verify_params
        params.permit(:password, :user_bundle_token)
      end

      def add_proofing_component(user)
        ProofingComponent.create_or_find_by(user: user).update(verified_at: Time.zone.now)
      end

      def completion_url(result, user)
        if result.extra[:profile_pending]
          idv_come_back_later_url
        elsif in_person_enrollment?(user)
          idv_in_person_ready_to_verify_url
        elsif device_profiling_failed?(user)
          idv_come_back_later_url
        elsif current_sp
          sign_up_completed_url
        else
          account_url
        end
      end

      def in_person_enrollment?(user)
        return false unless IdentityConfig.store.in_person_proofing_enabled
        ProofingComponent.find_by(user: user)&.document_check == Idp::Constants::Vendors::USPS
      end

      def device_profiling_failed?(user)
        return false unless IdentityConfig.store.proofing_device_profiling_decisioning_enabled
        proofing_component = ProofingComponent.find_by(user: user)
        proofing_component.threatmetrix_review_status != 'pass'
      end

      def handle_request_enroll_exception(err)
        analytics.idv_in_person_usps_request_enroll_exception(
          context: context,
          enrollment_id: err.enrollment_id,
          exception_class: err.class.to_s,
          original_exception_class: err.exception_class,
          exception_message: err.message,
          reason: 'Request exception',
        )
        render_errors(
          { internal: [
            I18n.t('idv.failure.exceptions.internal_error'),
          ] },
        )
      end
    end
  end
end
