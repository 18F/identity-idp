module Idv
  class Session
    VALID_SESSION_ATTRIBUTES = [
      :address_verification_mechanism,
      :applicant,
      :financials_confirmation,
      :params,
      :phone_confirmation,
      :pii,
      :profile_confirmation,
      :profile_id,
      :recovery_code,
      :resolution,
      :step_attempts,
      :vendor,
    ].freeze

    def initialize(user_session, current_user)
      @user_session = user_session
      @current_user = current_user
      @user_session[:idv] ||= new_idv_session
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
      resolution.present? && applicant.present? && resolution.success?
    end

    def cache_applicant_profile_id
      profile_maker = Idv::ProfileMaker.new(
        applicant: Proofer::Applicant.new(applicant_params),
        normalized_applicant: resolution.vendor_resp.normalized_applicant,
        user: current_user
      )
      profile = profile_maker.profile
      self.pii = profile_maker.pii_attributes
      self.profile_id = profile.id
      self.recovery_code = profile.recovery_code
    end

    def cache_encrypted_pii(password)
      cacher = Pii::Cacher.new(current_user, session)
      cacher.save(password, profile)
    end

    def applicant_from_params
      Proofer::Applicant.new(applicant_params_ascii.merge(uuid: current_user.uuid))
    end

    def profile
      @_profile ||= Profile.find(profile_id)
    end

    def clear
      user_session.delete(:idv)
    end

    def complete_session
      complete_profile if phone_confirmation == true
      create_usps_entry if address_verification_mechanism == :usps
    end

    def complete_profile
      profile.verified_at = Time.zone.now
      profile.vendor = vendor
      profile.activate
      move_pii_to_user_session
    end

    def create_usps_entry
      move_pii_to_user_session
      UspsConfirmationMaker.new(pii: pii).perform
    end

    def alive?
      session.present?
    end

    def address_mechanism_chosen?
      phone_confirmation == true || address_verification_mechanism == :usps
    end

    private

    attr_accessor :user_session, :current_user

    def new_idv_session
      { params: {}, step_attempts: { financials: 0, phone: 0 } }
    end

    def move_pii_to_user_session
      return unless session[:decrypted_pii].present?
      user_session[:decrypted_pii] = session.delete(:decrypted_pii)
    end

    def session
      user_session[:idv]
    end

    def applicant_params
      params.select { |key, _value| Proofer::Applicant.method_defined?(key) }
    end

    def applicant_params_ascii
      Hash[applicant_params.map { |key, value| [key, value.to_ascii] }]
    end
  end
end
