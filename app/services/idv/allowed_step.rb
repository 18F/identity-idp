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


    STEP_PRECONDITIONS = {
      welcome: [nil, welcome_proc],
      getting_started: [nil, welcome_proc],
      agreement: [nil, agreement_proc],
      hybrid_handoff: [nil, hybrid_handoff_proc],
      document_capture_standard: [nil, document_capture_standard_proc],
      document_capture_hybrid: [nil, document_capture_hybrid_proc],
      ssn: [ssn_predecessor_proc, ssn_proc]
    }


    # STEP_PRECONDITIONS = {
    #   welcome: [],
    #   getting_started: [],
    #   agreement: [:welcome, :welcome_visited],
    #   hybrid_handoff: [:agreement/:getting_started, :idv_consent_given],
    #   document_capture: [:hybrid_handoff, :flow_path],
    #   link_sent: [:welcome_visited, :idv_consent_given, :flow_path, :pii_from_doc],
    #   ssn: [:welcome_visited, :idv_consent_given, :flow_path, :pii_from_doc, ],
    # }

    def allowed_step(idv_session:, step:)
      STEP_PRECONDITIONS[step].first.call(idv_session)
      # gather_required_properties(step).all |prop| idv_session.send(prop)
    end

    def gather_step_preconditions(step)
      # chain through dependencies
    end

    def welcome_proc
      ->(idv_session) { true }
    end

    def agreement_proc
      ->(idv_session) do
        idv_session.welcome_visited
      end
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
