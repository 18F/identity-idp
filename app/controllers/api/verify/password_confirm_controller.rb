module Api
  module Verify
    class PasswordConfirmController < BaseController
      self.required_step = 'password_confirm'

      def create
        result, personal_key = form.submit

        if result.success?
          user = User.find_by(uuid: result.extra[:user_uuid])
          add_proofing_component(user)
          store_session_last_gpo_code(form.gpo_code)
          save_in_person_enrollment(user, form.profile)
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
        elsif current_sp
          sign_up_completed_url
        else
          account_url
        end
      end

      def in_person_enrollment?(user)
        return false unless IdentityConfig.store.in_person_proofing_enabled
        # WILLFIX: After LG-6872 and we have enrollment saved, reference enrollment instead.
        ProofingComponent.find_by(user: user)&.document_check == Idp::Constants::Vendors::USPS
      end

      def usps_proofer
        if IdentityConfig.store.usps_mock_fallback
          UspsInPersonProofing::Mock::Proofer.new
        else
          UspsInPersonProofing::Proofer.new
        end
      end

      def save_in_person_enrollment(user, profile)
        return unless in_person_enrollment?(user)

        # create enrollment in usps
        pii = user_session[:idv][:pii]
        applicant = UspsInPersonProofing::Applicant.new(
          {
            unique_id: user.uuid.delete('-').slice(0, 18),
            first_name: pii.first_name,
            last_name: pii.last_name,
            address: pii.address1,
            # do we need address2?
            city: pii.city,
            state: pii.state,
            zip_code: pii.zipcode,
            email: 'no-reply@login.gov',
          },
        )
        proofer = usps_proofer
        proofer.retrieve_token!
        # todo: any error handling?
        response = proofer.request_enroll(applicant)

        # create an enrollment in the db
        # todo: if this fails we could conveivably retry by querying the enrollment code from the USPS api. So may be create an upsert-like helper function to get an existing enrollment or create one if it doesn't exist
        enrollment_code = response['enrollmentCode']
        InPersonEnrollment.create!(
          user: user, enrollment_code: enrollment_code,
          status: :pending, profile: profile
        )
        # todo: display error banner on failure? check if raised exception rolls back the profile creation
      end
    end
  end
end
