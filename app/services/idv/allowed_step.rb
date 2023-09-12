module Idv
  class AllowedStep
    include IdvSession

    # proc for more complicated cases
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


    NEXT_STEPS = {
      welcome: [:agreement],
      getting_started: [:hybrid_handoff],
      agreement: [:hybrid_handoff, :document_capture_standard],
      hybrid_handoff: [:link_sent, :document_capture_standard],
      link_sent: [:ssn],
      document_capture_standard: [:ssn], # in person?
      ssn: [:verify_info],
      verify_info: [:ssn, :address, :hybrid_handoff, :document_capture_standard, :phone],
      phone: [:enter_otp, :request_letter],
      enter_otp: [:phone, :review],
      review: [:personal_key, :letter_enqueued],
      request_letter: [:review, :letter_enqueued],
    }

    attr_reader :idv_session

    def initialize(idv_session:)
      @idv_session = idv_session
    end

    def step_allowed?(step:)
      send(step)
    end

    def gather_step_preconditions(step)
      # chain through dependencies
    end

    def welcome
      true
    end

    def getting_started
      true
    end

    def agreement
      idv_session.welcome_visited
    end

    def hybrid_handoff_proc
      ->(idv_session) do
        idv_session.idv_consent_given
      end
    end

    def document_capture_standard_proc
      ->(idv_session) do
        idv_session.flow_path == 'standard'
      end
    end

    def document_capture_hybrid_proc
      ->(idv_session) do
        idv_session.flow_path == 'hybrid'
      end
    end

    def ssn_predecessor_proc
      ->(idv_session) do
        case idv_session.flow_path
        when 'standard'
          :document_capture_standard
        when 'hybrid'
          :document_capture_hybrid
        else
          nil
        end
      end
    end

    def ssn_proc
      ->(idv_session) do
        idv_session.pii_from_doc
      end
    end
  end
end
