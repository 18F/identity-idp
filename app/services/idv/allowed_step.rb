module Idv
  class AllowedStep
    # Possibly a /verify/resume controller
    # possibly chain the requirements here. (hybrid_handoff depends on agreement and one more thing)
    # Change polling to not depend on a specific screen (LinkSent)
    #   Could confirm leaving, but link is still out there.
    #   Invalidate document_capture_session? Message on phone
    #   If user submits images, we should try to continue
    #   successful upload count vs ssn viewed count (or link sent complete if available)
    # When hit back, confirm undo operation?
    # Back -> screen that summarizes what happened (like step indicator) w/links & start over button
    # Accessibility/screen readers
    # collect all info, then call vendors (store images)
    # send phone to IV at VerifyInfo step if we have it
    #   doesn't pass security review/user consent issues
    # require current_user as well?
    # add a/b test bucket to checks?
    #
    include Rails.application.routes.url_helpers

    NEXT_STEPS = Hash.new([])
    NEXT_STEPS.merge!(
      {
        root: [:welcome, :getting_started],
        welcome: [:agreement],
        agreement: [:hybrid_handoff, :document_capture],
        hybrid_handoff: [:link_sent, :document_capture],
        link_sent: [:ssn],
        document_capture: [:ssn], # in person?
        ssn: [:verify_info],
        verify_info: [:phone],
        phone: [:phone_enter_otp],
        phone_enter_otp: [:review],
        review: [:personal_key],
        # request_letter: [:review, :letter_enqueued], to be visited later
        # letter_enqueued: [:enter_verification_code],
        # enter_verification_code: [:personal_key],
        personal_key: [:success],
      },
    )

    attr_reader :idv_session, :user

    def initialize(idv_session:, user:)
      @idv_session = idv_session
      @user = user
    end

    def step_allowed?(step:)
      send(step)
    end

    def latest_step(current_step: :root)
      return nil if NEXT_STEPS[current_step].empty?
      return current_step if NEXT_STEPS[current_step] == [:success]

      (NEXT_STEPS[current_step]).each do |step|
        if step_allowed?(step: step)
          return latest_step(current_step: step)
        end
      end
      current_step
    end

    def path_for_latest_step
      path_map = {
        welcome: idv_welcome_path,
        agreement: idv_agreement_path,
        hybrid_handoff: idv_hybrid_handoff_path,
        document_capture: idv_document_capture_path,
        ssn: idv_ssn_path,
        verify_info: idv_verify_info_path,
        phone: idv_phone_path,
        phone_enter_otp: idv_otp_verification_path,
        review: idv_review_path,
        personal_key: idv_personal_key_path,
      }.freeze

      path_map[latest_step]
    end

    def welcome
      bucket = AbTests::IDV_GETTING_STARTED.bucket(user.uuid)
      bucket == :welcome_default || bucket == :welcome_new
    end

    def getting_started
      AbTests::IDV_GETTING_STARTED.bucket(user.uuid) == :getting_started
    end

    def agreement
      idv_session.welcome_visited
    end

    def hybrid_handoff
      idv_session.idv_consent_given
    end

    def document_capture
      idv_session.flow_path == 'standard'
    end

    def link_sent
      idv_session.flow_path == 'hybrid'
    end

    def ssn
      idv_session.pii_from_doc # ignoring in_person
    end

    def verify_info
      idv_session.ssn and idv_session.pii_from_doc
    end

    def phone
      idv_session.verify_info_step_complete? # controller code also needs applicant
    end

    def phone_enter_otp
      idv_session.user_phone_confirmation_session.present?
    end

    def review
      idv_session.verify_info_step_complete? &&
        idv_session.address_step_complete?
    end

    def request_letter
      idv_session.verify_info_step_complete?
    end

    def letter_enqueued
      (idv_session.blank? || idv_session.address_verification_mechanism == 'gpo') &&
        user.gpo_pending_profile?
    end

    def enter_verification_code
      user.gpo_pending_profile?
    end

    def personal_key
      user.identity_verified? # add a check for in-person
    end
  end
end
