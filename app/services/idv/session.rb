# frozen_string_literal: true

module Idv
  # @attr address_edited [Boolean, nil]
  # @attr address_verification_mechanism [String, nil]
  # @attr applicant [Struct, nil]
  # @attr doc_auth_vendor [String, nil]
  # @attr document_capture_session_uuid [String, nil]
  # @attr flow_path [String, nil]
  # @attr go_back_path [String, nil]
  # @attr gpo_code_verified [Boolean, nil]
  # @attr had_barcode_attention_error [Boolean, nil]
  # @attr had_barcode_read_failure [Boolean, nil]
  # @attr idv_consent_given [Boolean, nil]
  # @attr idv_consent_given_at [String, nil]
  # @attr idv_phone_step_document_capture_session_uuid [String, nil]
  # @attr mail_only_warning_shown [Boolean, nil]
  # @attr opted_in_to_in_person_proofing [Boolean, nil]
  # @attr passport_allowed [Boolean, nil]
  # @attr passport_requested [Boolean, nil]
  # @attr personal_key [String, nil]
  # @attr personal_key_acknowledged [Boolean, nil]
  # @attr phone_for_mobile_flow [String, nil]
  # @attr previous_phone_step_params [Array]
  # @attr previous_ssn [String, nil]
  # @attr profile_id [Integer, nil]
  # @attr proofing_started_at [String, nil]
  # @attr redo_document_capture [Boolean, nil]
  # @attr residential_resolution_vendor [String, nil]
  # @attr resolution_successful [Boolean, nil]
  # @attr resolution_vendor [String,nil]
  # @attr selfie_check_performed [Boolean, nil]
  # @attr selfie_check_required [Boolean, nil]
  # @attr skip_doc_auth_from_handoff [Boolean, nil]
  # @attr skip_doc_auth_from_how_to_verify [Boolean, nil]
  # @attr skip_hybrid_handoff [Boolean, nil]
  # @attr source_check_vendor [String, nil]
  # @attr ssn [String, nil]
  # @attr threatmetrix_review_status [String, nil]
  # @attr threatmetrix_session_id [String, nil]
  # @attr user_phone_confirmation [Boolean, nil]
  # @attr vendor_phone_confirmation [Boolean, nil]
  # @attr verify_info_step_document_capture_session_uuid [String, nil]
  # @attr welcome_visited [Boolean, nil]
  # @attr_reader current_user [User]
  # @attr_reader gpo_otp [String, nil]
  # @attr_reader service_provider [ServiceProvider]
  class Session
    VALID_SESSION_ATTRIBUTES = %i[
      address_edited
      address_verification_mechanism
      applicant
      bucketed_doc_auth_vendor
      doc_auth_vendor
      document_capture_session_uuid
      flow_path
      go_back_path
      gpo_code_verified
      had_barcode_attention_error
      had_barcode_read_failure
      idv_consent_given
      idv_consent_given_at
      idv_phone_step_document_capture_session_uuid
      mail_only_warning_shown
      opted_in_to_in_person_proofing
      passport_allowed
      personal_key
      personal_key_acknowledged
      phone_for_mobile_flow
      previous_phone_step_params
      previous_ssn
      profile_id
      proofing_started_at
      redo_document_capture
      residential_resolution_vendor
      resolution_successful
      resolution_vendor
      selfie_check_performed
      selfie_check_required
      skip_doc_auth_from_handoff
      skip_doc_auth_from_how_to_verify
      skip_doc_auth_from_socure
      skip_hybrid_handoff
      socure_docv_wait_polling_started_at
      source_check_vendor
      ssn
      threatmetrix_review_status
      threatmetrix_session_id
      user_phone_confirmation
      vendor_phone_confirmation
      verify_info_step_document_capture_session_uuid
      welcome_visited
    ].freeze

    attr_reader :current_user, :gpo_otp, :service_provider

    VALID_SESSION_ATTRIBUTES.each do |attr|
      define_method(attr) do
        session[attr]
      end

      define_method(:"#{attr}=") do |val|
        session[attr] = val
      end
    end

    def initialize(user_session:, current_user:, service_provider:)
      @user_session = user_session
      @current_user = current_user
      @service_provider = service_provider
      set_idv_session
    end

    # @return [Profile]
    def create_profile_from_applicant_with_password(
      user_password, is_enhanced_ipp:, proofing_components:
    )
      if user_has_unscheduled_in_person_enrollment?
        UspsInPersonProofing::EnrollmentHelper.schedule_in_person_enrollment(
          user: current_user,
          pii: Pii::Attributes.new_from_hash(applicant),
          is_enhanced_ipp: is_enhanced_ipp,
          opt_in: opt_in_param,
        )
      end

      profile_maker = build_profile_maker(user_password)
      profile = profile_maker.save_profile(
        fraud_pending_reason: threatmetrix_fraud_pending_reason,
        gpo_verification_needed: !phone_confirmed? || verify_by_mail?,
        in_person_verification_needed: current_user.has_in_person_enrollment?,
        selfie_check_performed: session[:selfie_check_performed],
        proofing_components:,
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
        create_gpo_entry(profile_maker.pii_attributes, profile)
      end

      profile
    end

    def opt_in_param
      opted_in_to_in_person_proofing unless !IdentityConfig.store.in_person_proofing_opt_in_enabled
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
      @profile = nil
      @gpo_otp = nil
    end

    def associate_in_person_enrollment_with_profile
      current_user.establishing_in_person_enrollment.update(profile: profile)
    end

    def create_gpo_entry(pii, profile)
      begin
        confirmation_maker = GpoConfirmationMaker.new(
          pii: pii, service_provider: service_provider,
          profile: profile
        )
        confirmation_maker.perform

        @gpo_otp = confirmation_maker.otp
      rescue
        # We don't have what we need to actually generate a GPO letter.
        profile.deactivate(:encryption_error)
        raise
      end
    end

    def phone_otp_sent?
      vendor_phone_confirmation && address_verification_mechanism == 'phone'
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

    def pii_from_doc=(new_pii_from_doc)
      if new_pii_from_doc.blank?
        session[:pii_from_doc] = nil
      else
        session[:pii_from_doc] = new_pii_from_doc.to_h
      end
    end

    def pii_from_doc
      return nil if session[:pii_from_doc].blank?
      if session[:passport_requested]
        passport_data = Pii::Passport.members.index_with { |key| session[:pii_from_doc][key] }
        Pii::Passport.new(**passport_data)
      else
        state_id_data = Pii::StateId.members.index_with { |key| session[:pii_from_doc][key] }
        Pii::StateId.new(**state_id_data)
      end
    end

    def updated_user_address=(updated_user_address)
      if updated_user_address.blank?
        session[:updated_user_address] = nil
      else
        session[:updated_user_address] = updated_user_address.to_h
      end
    end

    def updated_user_address
      return nil if session[:updated_user_address].blank?
      Pii::Address.new(**session[:updated_user_address])
    end

    def add_failed_phone_step_number(phone)
      parsed_phone = Phonelib.parse(phone)
      phone_e164 = parsed_phone.e164
      failed_phone_step_numbers << phone_e164 if !failed_phone_step_numbers.include?(phone_e164)
    end

    def proofing_workflow_time_in_seconds
      Time.zone.now - Time.zone.parse(proofing_started_at) if proofing_started_at.present?
    end

    def pii_from_user_in_session
      user_session.dig('idv/in_person', :pii_from_user)
    end

    def has_pii_from_user_in_session?
      !!pii_from_user_in_session
    end

    def invalidate_in_person_pii_from_user!
      if has_pii_from_user_in_session?
        user_session['idv/in_person'][:pii_from_user] = nil
      end
    end

    def invalidate_in_person_address_step!
      if has_pii_from_user_in_session?
        user_session['idv/in_person'][:pii_from_user][:address1] = nil
        user_session['idv/in_person'][:pii_from_user][:address2] = nil
        user_session['idv/in_person'][:pii_from_user][:city] = nil
        user_session['idv/in_person'][:pii_from_user][:zipcode] = nil
        user_session['idv/in_person'][:pii_from_user][:state] = nil
      end
    end

    def remote_document_capture_complete?
      pii_from_doc.present?
    end

    def ipp_document_capture_complete?
      has_pii_from_user_in_session? &&
        user_session['idv/in_person'][:pii_from_user].has_key?(:address1)
    end

    def ipp_state_id_complete?
      has_pii_from_user_in_session? &&
        user_session['idv/in_person'][:pii_from_user].has_key?(:identity_doc_address1)
    end

    def ssn_step_complete?
      ssn.present?
    end

    def invalidate_ssn_step!
      if user_session[:idv].has_key?(:ssn)
        user_session[:idv].delete(:ssn)
      end
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

    def mark_phone_step_started!
      session[:address_verification_mechanism] = 'phone'
      session[:vendor_phone_confirmation] = true
      session[:user_phone_confirmation] = false
    end

    def mark_phone_step_complete!
      session[:user_phone_confirmation] = true
    end

    def invalidate_phone_step!
      session[:address_verification_mechanism] = nil
      session[:vendor_phone_confirmation] = nil
      session[:user_phone_confirmation] = nil
    end

    def skip_hybrid_handoff?
      !!session[:skip_hybrid_handoff]
    end

    def desktop_selfie_test_mode_enabled?
      IdentityConfig.store.doc_auth_selfie_desktop_test_mode
    end

    def idv_consent_given?
      !!session[:idv_consent_given_at]
    end

    private

    attr_reader :user_session

    def set_idv_session
      user_session[:idv] = new_idv_session unless user_session.key?(:idv)
    end

    def new_idv_session
      {}
    end

    def session
      user_session[:idv] || {}
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

    def user_has_unscheduled_in_person_enrollment?
      current_user.has_establishing_in_person_enrollment?
    end
  end
end
