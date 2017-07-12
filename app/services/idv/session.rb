module Idv
  class Session
    VALID_SESSION_ATTRIBUTES = %i[
      async_result_id
      address_verification_mechanism
      applicant
      financials_confirmation
      normalized_applicant_params
      params
      phone_confirmation
      pii
      profile_confirmation
      profile_id
      personal_key
      resolution_successful
      step_attempts
      vendor
      vendor_session_id
    ].freeze

    attr_reader :current_user

    def initialize(user_session:, current_user:, issuer:)
      @user_session = user_session
      @current_user = current_user
      @issuer = issuer
      set_idv_session
    end

    def method_missing(method_sym, *arguments, &block)
      attr_name_sym = method_sym.to_s.gsub(/=\z/, '').to_sym
      if VALID_SESSION_ATTRIBUTES.include?(attr_name_sym)
        return session[attr_name_sym] if arguments.empty?
        session[attr_name_sym] = arguments.first
      else
        super
      end
    end

    def respond_to_missing?(method_sym, include_private)
      attr_name_sym = method_sym.to_s.gsub(/=\z/, '').to_sym
      VALID_SESSION_ATTRIBUTES.include?(attr_name_sym) || super
    end

    def proofing_started?
      applicant.present? && resolution_successful
    end

    def cache_applicant_profile_id
      profile = profile_maker.profile
      self.pii = profile_maker.pii_attributes
      self.profile_id = profile.id
      self.personal_key = profile.personal_key
    end

    def cache_encrypted_pii(password)
      cacher = Pii::Cacher.new(current_user, session)
      cacher.save(password, profile)
    end

    def vendor_params
      applicant_params_ascii.merge('uuid' => current_user.uuid)
    end

    def profile
      @_profile ||= Profile.find(profile_id)
    end

    def clear
      user_session.delete(:idv)
    end

    def complete_session
      complete_profile if phone_confirmation == true
      create_usps_entry if address_verification_mechanism == 'usps'
    end

    def complete_profile
      ProfileActivator.new(user: current_user).call
      move_pii_to_user_session
    end

    def create_usps_entry
      move_pii_to_user_session
      if pii.is_a?(String)
        self.pii = Pii::Attributes.new_from_json(user_session[:decrypted_pii])
      end

      UspsConfirmationMaker.new(pii: pii, issuer: issuer).perform
    end

    def alive?
      session.present?
    end

    def address_mechanism_chosen?
      phone_confirmation == true || address_verification_mechanism == 'usps'
    end

    private

    attr_accessor :user_session, :issuer

    def set_idv_session
      return if session.present?
      user_session[:idv] = new_idv_session
    end

    def new_idv_session
      { params: {}, step_attempts: { financials: 0, phone: 0 } }
    end

    def move_pii_to_user_session
      return if session[:decrypted_pii].blank?
      user_session[:decrypted_pii] = session.delete(:decrypted_pii)
    end

    def session
      user_session.fetch(:idv, {})
    end

    def applicant_params
      params.select { |key, _value| Proofer::Applicant.method_defined?(key) }
    end

    def applicant_params_ascii
      Hash[applicant_params.map { |key, value| [key, value.to_ascii] }]
    end

    def profile_maker
      @_profile_maker ||= Idv::ProfileMaker.new(
        applicant: Proofer::Applicant.new(applicant_params),
        normalized_applicant: Proofer::Applicant.new(normalized_applicant_params),
        phone_confirmed: phone_confirmation || false,
        user: current_user,
        vendor: vendor
      )
    end
  end
end
