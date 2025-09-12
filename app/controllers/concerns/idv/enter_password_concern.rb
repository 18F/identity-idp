# frozen_string_literal: true

module Idv
  # @attr idv_session [Idv::Session]
  module EnterPasswordConcern
    extend ActiveSupport::Concern

    def init_profile
      reproof = current_user.has_proofed_before?
      profile = idv_session.create_profile_from_applicant_with_password(
        password,
        is_enhanced_ipp: resolved_authn_context_result.enhanced_ipp?,
        proofing_components: ProofingComponents.new(idv_session:).to_h,
      )

      if profile.gpo_verification_pending?
        current_user.send_email_to_all_addresses(:verify_by_mail_letter_requested)
        log_letter_enqueued_analytics(resend: false)
      end

      if profile.fraud_review_pending? && !profile.in_person_verification_pending?
        current_user.send_email_to_all_addresses(:idv_please_call)
      end

      if profile.active?
        create_user_event(:account_verified)
        UserAlerts::AlertUserAboutAccountVerified.call(
          profile: idv_session.profile,
        )
        attempts_api_tracker.idv_enrollment_complete(reproof:)
      end
    end
  end
end
