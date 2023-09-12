module Idv
  class AllowedStep
    # Possibly a /verify/resume controller
    # possibly chain the requirements here. (hybrid_handoff depends on agreement and one more thing)
    # Change polling to not depend on a specific screen (LinkSent)
      # Could confirm leaving, but link is still out there.
      # Invalidate document_capture_session? Message on phone
      # If user submits images, we should try to continue
      # successful upload count vs ssn viewed count (or link sent complete if available)
    # When hit back, confirm undo operation?
    # Back -> screen that summarizes what happened (like step indicator) w/links & start over button
    # Accessibility/screen readers
    # collect all info, then call vendors (store images)
    # send phone to IV at VerifyInfo step if we have it
      # doesn't pass security review/user consent issues
    # require current_user as well?

    NEXT_STEPS = Hash.new([])
    NEXT_STEPS.merge!(
      {
        root: [:welcome],
        welcome: [:agreement],
        agreement: [:hybrid_handoff, :document_capture],
        hybrid_handoff: [:link_sent, :document_capture],
        link_sent: [:ssn],
        document_capture: [:ssn], # in person?
        ssn: [:verify_info],
        verify_info: [:ssn, :address, :hybrid_handoff, :document_capture, :phone],
        phone: [:enter_otp, :request_letter],
        enter_otp: [:phone, :review],
        review: [:personal_key, :letter_enqueued],
        request_letter: [:review, :letter_enqueued],
      },
    )

    attr_reader :idv_session

    def initialize(idv_session:)
      @idv_session = idv_session
    end

    def step_allowed?(step:)
      send(step)
    end

    def latest_step(current_step: :root)
      return nil if NEXT_STEPS[current_step].empty?

      (NEXT_STEPS[current_step]).each do |step|
        if step_allowed?(step: step)
          return latest_step(current_step: step)
        end
      end
      current_step
    end

    def welcome
      true
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

    def enter_otp
      idv_session.user_phone_confirmation_session
    end

    def review
      idv_session.verify_info_step_complete? &&
        idv_session.address_step_complete?
    end

    def request_letter
      idv_session.verify_info_step_complete?
    end
  end
end
