module Idv
  class Session
    VALID_SESSION_ATTRIBUTES = [
      :resolution, :vendor, :applicant, :params, :profile_id, :recovery_code,
      :financials_confirmation, :phone_confirmation
    ].freeze

    def initialize(user_session, current_user)
      @user_session = user_session
      @current_user = current_user
      @user_session[:idv] ||= { params: {} }
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

    def cache_applicant_profile_id(applicant)
      profile = Idv::ProfileFromApplicant.create(applicant, current_user)
      self.profile_id = profile.id
      self.recovery_code = profile.recovery_code
    end

    def cache_encrypted_pii(password)
      cacher = Pii::Cacher.new(current_user, session)
      cacher.save(password, profile)
    end

    def applicant_from_params
      app_vars = params.select { |key, _value| Proofer::Applicant.method_defined?(key) }
      Proofer::Applicant.new(app_vars)
    end

    def profile
      @_profile ||= Profile.find(profile_id)
    end

    def clear
      user_session.delete(:idv)
    end

    def complete_profile
      profile.verified_at = Time.zone.now
      profile.vendor = vendor
      profile.activate
      move_pii_to_user_session
    end

    def alive?
      session.present?
    end

    private

    attr_accessor :user_session, :current_user

    def move_pii_to_user_session
      user_session[:decrypted_pii] = session.delete(:decrypted_pii)
    end

    def session
      user_session[:idv]
    end
  end
end
