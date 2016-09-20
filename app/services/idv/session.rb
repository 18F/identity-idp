module Idv
  class Session
    delegate :questions, to: :resolution

    def initialize(user_session, current_user)
      @user_session = user_session
      @current_user = current_user
      @user_session[:idv] ||= {}
    end

    def attempts=(num)
      current_user.update!(idv_attempts: num)
    end

    def attempts
      current_user.idv_attempts
    end

    def attempter
      @_attempter ||= Idv::Attempter.new(current_user)
    end

    def flag_user_attempt
      self.attempts += 1
      current_user.update!(idv_attempted_at: Time.zone.now)
    end

    def question_number
      session[:question_number] ||= 0
    end

    def resolution
      session[:resolution]
    end

    def proofing_started?
      resolution.present? && applicant.present? && resolution.success?
    end

    def vendor=(vendor)
      session[:vendor] = vendor
    end

    def applicant=(applicant)
      session[:applicant] = applicant
    end

    def profile_from_applicant(applicant)
      self.profile_id = Profile.create_from_proofer_applicant(applicant, current_user).id
    end

    def resolution=(resolution)
      session[:resolution] = resolution
    end

    def question_number=(num)
      session[:question_number] = num
    end

    def params=(idv_params)
      session[:params] = idv_params
    end

    def vendor
      session[:vendor]
    end

    def applicant
      session[:applicant]
    end

    def profile_id
      session[:profile_id]
    end

    def profile_id=(profile_id)
      session[:profile_id] = profile_id
    end

    def params
      session[:params] ||= {}
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
  end
end
