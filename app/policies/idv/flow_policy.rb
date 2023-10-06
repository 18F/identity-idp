module Idv
  class FlowPolicy
    include Rails.application.routes.url_helpers

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
        verify_info: [:phone],
        phone: [:phone_enter_otp],
        phone_enter_otp: [:review],
        review: [:personal_key],
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

    def path_allowed?(path:)
      step = path_to_step[path]
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
      path_map[latest_step]
    end

    # This can be blank because we are using paths, not urls,
    # so international urls are supported.
    def url_options
      {}
    end

    private

    def path_to_step
      @path_to_step ||= {
        idv_welcome_path => :welcome,
        idv_agreement_path => :agreement,
        idv_hybrid_handoff_path => :hybrid_handoff,
        idv_link_sent_path => :link_sent,
        idv_document_capture_path => :document_capture,
        idv_ssn_path => :ssn,
        idv_verify_info_path => :verify_info,
        idv_phone_path => :phone,
        idv_otp_verification_path => :phone_enter_otp,
        idv_review_path => :review,
        idv_personal_key_path => :personal_key,
      }.freeze
    end

    def path_map
      @path_map ||= {
        welcome: idv_welcome_path,
        agreement: idv_agreement_path,
        hybrid_handoff: idv_hybrid_handoff_path,
        link_sent: idv_link_sent_path,
        document_capture: idv_document_capture_path,
        ssn: idv_ssn_path,
        verify_info: idv_verify_info_path,
        phone: idv_phone_path,
        phone_enter_otp: idv_otp_verification_path,
        review: idv_review_path,
        personal_key: idv_personal_key_path,
      }.freeze
    end

    def welcome
      return true
    end

    def agreement
      idv_session.welcome_visited
    end

    def hybrid_handoff
      idv_session.idv_consent_given
      # look into covering verify info step not complete also
    end

    def document_capture
      idv_session.flow_path == 'standard'
    end

    def link_sent
      idv_session.flow_path == 'hybrid'
    end

    def ssn
      post_document_capture_check
    end

    def verify_info
      idv_session.ssn && post_document_capture_check
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

    def post_document_capture_check
      idv_session.pii_from_doc.present? || idv_session.resolution_successful # ignoring in_person
    end
  end
end
