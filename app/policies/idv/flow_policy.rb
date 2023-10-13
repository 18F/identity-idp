module Idv
  class FlowPolicy
    include Rails.application.routes.url_helpers
    attr_reader :idv_session, :user

    Step = Struct.new(:path, :next_steps, :requirements)

    def initialize(idv_session:, user:)
      @idv_session = idv_session
      @user = user
    end

    def step_allowed?(step:)
      steps[step].requirements.call
    end

    def path_allowed?(path:)
      step = path_to_step(path: path)
      step_allowed?(step: step)
    end

    def latest_step(current_step: :root)
      return nil if steps[current_step].next_steps.empty?
      return current_step if steps[current_step].next_steps == [:success]

      steps[current_step].next_steps.each do |step|
        if step_allowed?(step: step)
          return latest_step(current_step: step)
        end
      end
      current_step
    end

    def path_for_latest_step
      steps[latest_step].path
    end

    # This can be blank because we are using paths, not urls,
    # so international urls are supported.
    def url_options
      {}
    end

    private

    def steps
      blank_step = Step.new(path: nil, next_steps: [], requirements: -> { false })
      Hash.new(blank_step).merge(
        {
          root: Step.new(next_steps: [:welcome]),
          welcome: Step.new(
            path: idv_welcome_path,
            next_steps: [:agreement],
            requirements: -> { true },
            ),
          agreement: Step.new(
            path: idv_agreement_path,
            next_steps: [:hybrid_handoff, :document_capture],
            requirements: -> { idv_session.welcome_visited },
            ),
          hybrid_handoff: Step.new(
            path: idv_hybrid_handoff_path,
            next_steps: [:link_sent, :document_capture],
            requirements: -> { idv_session.idv_consent_given },
            ),
          link_sent: Step.new(
            path: idv_link_sent_path,
            next_steps: [:ssn],
            requirements: -> { idv_session.flow_path == 'hybrid' },
            ),
          document_capture: Step.new(
            path: idv_document_capture_path,
            next_steps: [:ssn],
            requirements: -> { idv_session.flow_path == 'standard' },
            ),
          ssn: Step.new(
            path: idv_ssn_path,
            next_steps: [:verify_info],
            requirements: -> { post_document_capture_check },
            ),
          verify_info: Step.new(
            path: idv_verify_info_path,
            next_steps: [:phone],
            requirements: -> { idv_session.ssn && post_document_capture_check },
            ),
          phone: Step.new(
            path: idv_phone_path,
            next_steps: [:phone_enter_otp],
            requirements: -> { idv_session.verify_info_step_complete? },
            ),
          phone_enter_otp: Step.new(
            path: idv_otp_verification_path,
            next_steps: [:review],
            requirements: -> do
              idv_session.user_phone_confirmation_session.present?
            end,
            ),
          review: Step.new(
            path: idv_review_path,
            next_steps: [:personal_key],
            requirements: -> do
              idv_session.verify_info_step_complete? &&
                idv_session.address_step_complete?
            end,
            ),
          personal_key: Step.new(
            path: idv_personal_key_path,
            next_steps: [:success],
            requirements: -> { user.identity_verified? },
            ),
        },
        )
    end

    def path_to_step(path:)
      steps.keys.each do |key|
        return key if steps[key].path == path
      end
    end

    def post_document_capture_check
      idv_session.pii_from_doc.present? || idv_session.resolution_successful # ignoring in_person
    end
  end
end
