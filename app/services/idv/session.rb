module Idv
  class Session
    delegate :questions, to: :resolution

    VALID_SESSION_ATTRIBUTES = [
      :question_number, :resolution, :vendor, :applicant, :params, :profile_id
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

    def profile_from_applicant(applicant, password)
      profile = Idv::Applicant.new(applicant, current_user, password).profile
      self.profile_id = profile.id
      cache_encrypted_pii(password)
      profile
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
      # move from temp slot to 'permanent' slot
      user_session[:encrypted_pii] = session.delete(:encrypted_pii)
    end

    def alive?
      session.present?
    end

    def answer_next_question(question_number, answer)
      questions[question_number].answer = answer
      self.question_number += 1
    end

    private

    attr_accessor :user_session, :current_user

    def session
      user_session[:idv]
    end

    def cache_encrypted_pii(password)
      cacher = Pii::Cacher.new(current_user, session)
      cacher.save(password, profile)
    end
  end
end
