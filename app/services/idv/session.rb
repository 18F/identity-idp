module Idv
  class Session
    VALID_SESSION_ATTRIBUTES = %i[
      address_edited
      address_verification_mechanism
      applicant
      document_capture_session_uuid
      flow_path
      go_back_path
      gpo_code_verified
      had_barcode_attention_error
      had_barcode_read_failure
      idv_consent_given
      idv_phone_step_document_capture_session_uuid
      mail_only_warning_shown
      personal_key
      personal_key_acknowledged
      phone_for_mobile_flow
      phone_with_camera
      pii_from_doc
      previous_phone_step_params
      profile_id
      redo_document_capture
      resolution_successful
      skip_doc_auth
      skip_hybrid_handoff
      ssn
      threatmetrix_review_status
      threatmetrix_session_id
      user_phone_confirmation
      vendor_phone_confirmation
      verify_info_step_document_capture_session_uuid
      welcome_visited
    ].freeze

    attr_reader :current_user, :gpo_otp, :service_provider

    def initialize(user_session:, current_user:, service_provider:)
      @user_session = user_session
      @current_user = current_user
      @service_provider = service_provider
      set_idv_session
    end

    def method_missing(method_sym, *arguments, &block)
      attr_name_sym = method_sym.to_s.delete_suffix('=').to_sym
      if VALID_SESSION_ATTRIBUTES.include?(attr_name_sym)
        return session[attr_name_sym] if arguments.empty?
        session[attr_name_sym] = arguments.first
      else
        super
      end
    end

    def respond_to_missing?(method_sym, include_private)
      attr_name_sym = method_sym.to_s.delete_suffix('=').to_sym
      VALID_SESSION_ATTRIBUTES.include?(attr_name_sym) || super
    end

    def create_profile_from_applicant_with_password(user_password)
      profile_maker = build_profile_maker(user_password)
      profile = profile_maker.save_profile(
        fraud_pending_reason: threatmetrix_fraud_pending_reason,
        gpo_verification_needed: !phone_confirmed? || verify_by_mail?,
        in_person_verification_needed: current_user.has_in_person_enrollment?,
      )

      profile.activate unless profile.reason_not_to_activate

      self.profile_id = profile.id
      self.personal_key = profile.personal_key

      Pii::Cacher.new(current_user, user_session).save_decrypted_pii(
        profile_maker.pii_attributes,
        profile.id,
      )

      associate_in_person_enrollment_with_profile if profile.in_person_verification_pending?

      if profile.gpo_verification_pending?
        create_gpo_entry(profile_maker.pii_attributes)
      elsif profile.in_person_verification_pending?
        UspsInPersonProofing::EnrollmentHelper.schedule_in_person_enrollment(
          current_user,
          profile_maker.pii_attributes,
        )
      end
    end

    def acknowledge_personal_key!
      session.delete(:personal_key)
      session[:personal_key_acknowledged] = true
    end

    def invalidate_personal_key!
      session.delete(:personal_key)
      session.delete(:personal_key_acknowledged)
    end

    def verify_by_mail?
      address_verification_mechanism == 'gpo'
    end

    def vendor_params
      applicant.merge('uuid' => current_user.uuid)
    end

    def profile_id=(value)
      session[:profile_id] = value
      @profile = nil
    end

    def profile
      @profile ||= Profile.find_by(id: profile_id)
    end

    def clear
      user_session.delete(:idv)
    end

    def associate_in_person_enrollment_with_profile
      current_user.establishing_in_person_enrollment.update(profile: profile)
    end

    def create_gpo_entry(pii)
      confirmation_maker = GpoConfirmationMaker.new(
        pii: pii, service_provider: service_provider,
        profile: profile
      )
      confirmation_maker.perform

      @gpo_otp = confirmation_maker.otp
    end

    def phone_otp_sent?
      user_phone_confirmation_session.present?
    end

    def user_phone_confirmation_session
      session_value = session[:user_phone_confirmation_session]
      return if session_value.blank?
      Idv::PhoneConfirmationSession.from_h(session_value)
    end

    def user_phone_confirmation_session=(new_user_phone_confirmation_session)
      session[:user_phone_confirmation_session] = new_user_phone_confirmation_session.to_h
    end

    def failed_phone_step_numbers
      session[:failed_phone_step_params] ||= []
    end

    def add_failed_phone_step_number(phone)
      parsed_phone = Phonelib.parse(phone)
      phone_e164 = parsed_phone.e164
      failed_phone_step_numbers << phone_e164 if !failed_phone_step_numbers.include?(phone_e164)
    end

    def has_pii_from_user_in_flow_session
      user_session.dig('idv/in_person', :pii_from_user)
    end

    def invalidate_in_person_pii_from_user!
      if has_pii_from_user_in_flow_session
        user_session['idv/in_person'][:pii_from_user] = nil
      end
    end

    def document_capture_complete?
      pii_from_doc || has_pii_from_user_in_flow_session
    end

    def remote_document_capture_complete?
      pii_from_doc
    end

    def ipp_document_capture_complete?
      has_pii_from_user_in_flow_session
    end

    def verify_info_step_complete?
      resolution_successful
    end

    def phone_or_address_step_complete?
      verify_by_mail? || phone_confirmed?
    end

    def address_mechanism_chosen?
      vendor_phone_confirmation == true || verify_by_mail?
    end

    def phone_confirmed?
      vendor_phone_confirmation == true && user_phone_confirmation == true
    end

    def address_confirmed?
      gpo_code_verified == true
    end

    def address_confirmed!
      session[:gpo_code_verified] = true
    end

    def mark_verify_info_step_complete!
      session[:resolution_successful] = true
    end

    def invalidate_verify_info_step!
      session[:resolution_successful] = nil
    end

    def invalidate_phone_step!
      session[:vendor_phone_confirmation] = nil
      session[:user_phone_confirmation] = nil
    end

    def skip_hybrid_handoff?
      !!session[:skip_hybrid_handoff]
    end

    private

    attr_accessor :user_session

    def set_idv_session
      user_session[:idv] = new_idv_session unless user_session.key?(:idv)
    end

    def new_idv_session
      {}
    end

    def session
      user_session.fetch(:idv, {})
    end

    def build_profile_maker(user_password)
      Idv::ProfileMaker.new(
        applicant: applicant,
        user: current_user,
        user_password: user_password,
        initiating_service_provider: service_provider,
      )
    end

    def threatmetrix_fraud_pending_reason
      return if !FeatureManagement.proofing_device_profiling_decisioning_enabled?

      case threatmetrix_review_status
      when 'reject'
        'threatmetrix_reject'
      when 'review'
        'threatmetrix_review'
      end
    end
  end
end
