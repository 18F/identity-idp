module Idv
  class Session
    VALID_SESSION_ATTRIBUTES = %i[
      address_verification_mechanism
      applicant
      idv_phone_step_document_capture_session_uuid
      idv_gpo_document_capture_session_uuid
      vendor_phone_confirmation
      user_phone_confirmation
      pii
      previous_phone_step_params
      previous_profile_step_params
      previous_gpo_step_params
      profile_confirmation
      profile_id
      profile_step_params
      personal_key
      resolution_successful
    ].freeze

    attr_reader :current_user, :gpo_otp, :issuer

    def initialize(user_session:, current_user:, issuer:)
      @user_session = user_session
      @current_user = current_user
      @issuer = issuer
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

    def proofing_started?
      applicant.present? && resolution_successful
    end

    def create_profile_from_applicant_with_password(user_password)
      profile_maker = build_profile_maker(user_password)
      profile = profile_maker.save_profile
      self.pii = profile_maker.pii_attributes
      self.profile_id = profile.id
      self.personal_key = profile.personal_key
    end

    def cache_encrypted_pii(password)
      cacher = Pii::Cacher.new(current_user, session)
      cacher.save(password, profile)
    end

    def vendor_params
      applicant.merge('uuid' => current_user.uuid)
    end

    def profile
      @_profile ||= Profile.find_by(id: profile_id)
    end

    def clear
      user_session.delete(:idv)
    end

    def phone_confirmed?
      vendor_phone_confirmation == true && user_phone_confirmation == true
    end

    def complete_session
      complete_profile if phone_confirmed?
      create_gpo_entry if address_verification_mechanism == 'gpo'
    end

    def complete_profile
      current_user.pending_profile&.activate
      move_pii_to_user_session
    end

    def create_gpo_entry
      move_pii_to_user_session
      self.pii = Pii::Attributes.new_from_json(user_session[:decrypted_pii]) if pii.is_a?(String)
      confirmation_maker = GpoConfirmationMaker.new(pii: pii, issuer: issuer, profile: profile)
      confirmation_maker.perform

      @gpo_otp = confirmation_maker.otp
    end

    def alive?
      session.present?
    end

    def address_mechanism_chosen?
      vendor_phone_confirmation == true || address_verification_mechanism == 'gpo'
    end

    def user_phone_confirmation_session
      session_value = session[:user_phone_confirmation_session]
      return if session_value.blank?
      PhoneConfirmation::ConfirmationSession.from_h(session_value)
    end

    def user_phone_confirmation_session=(new_user_phone_confirmation_session)
      session[:user_phone_confirmation_session] = new_user_phone_confirmation_session.to_h
    end

    def document_expired
      user_session.dig('idv/doc_auth', :document_expired) # via flow_session[:document_expired]
    end

    private

    attr_accessor :user_session

    def set_idv_session
      return if session.present?
      user_session[:idv] = new_idv_session
    end

    def new_idv_session
      {}
    end

    def move_pii_to_user_session
      return if session[:decrypted_pii].blank?
      user_session[:decrypted_pii] = session.delete(:decrypted_pii)
    end

    def session
      user_session.fetch(:idv, {})
    end

    def build_profile_maker(user_password)
      Idv::ProfileMaker.new(
        applicant: applicant,
        user: current_user,
        user_password: user_password,
        document_expired: document_expired,
      )
    end
  end
end
