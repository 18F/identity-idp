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
      welcome: [],
      getting_started: [],
      agreement: [:welcome_visited],
      hybrid_handoff: [:welcome_visited, :idv_consent_given],
      document_capture: [:welcome_visited, :idv_consent_given, :flow_path],
      link_sent: [:welcome_visited, :idv_consent_given, :flow_path, :pii_from_doc],
      ssn: [:welcome_visited, :idv_consent_given, :flow_path, :pii_from_doc, ],
      (proc)

    }


    STEP_PRECONDITIONS = {
      welcome: [],
      getting_started: [],
      agreement: [:welcome, :welcome_visited],
      hybrid_handoff: [:agreement/:getting_started, :idv_consent_given],
      document_capture: [:hybrid_handoff, :flow_path],
      link_sent: [:welcome_visited, :idv_consent_given, :flow_path, :pii_from_doc],
      ssn: [:welcome_visited, :idv_consent_given, :flow_path, :pii_from_doc, ],
      (proc_predecessor, proc_requirements

    }

    def allowed_step(idv_session:, step:)
      gather_required_properties(step).all |prop| idv_session.send(prop)
    end

    def gather_step_preconditions(step)
      # chain through dependencies
    end
  end
end