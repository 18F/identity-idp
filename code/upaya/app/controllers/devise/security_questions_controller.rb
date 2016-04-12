module Devise
  class SecurityQuestionsController < DeviseController
    include ScopeAuthenticator

    prepend_before_action :authenticate_scope!, except: [:confirm, :check]
    before_action :confirm_two_factor_setup, except: [:confirm, :check]
    before_action :confirm_two_factor_authenticated, except: [:confirm, :check]
    before_action :assign_resource, only: [:confirm, :check]
    before_action :check_attempts_exceeded, only: [:confirm, :check]

    NUM_SECURITY_QUESTIONS_TO_CONFIRM = 3

    def update # or create
      if user_valid?(current_user) && current_user.security_questions_enabled?
        flash[:notice] = t('upaya.notices.secret_questions_created')
        redirect_to dashboard_index_url
      else
        flash[:error] = t('upaya.errors.duplicate_questions')
        render :new
      end
    end

    def new
      num_questions_needed = User::NUM_SECURITY_QUESTIONS - resource.security_answers.size
      num_questions_needed.times do
        resource.security_answers.build
      end
    end

    def confirm
      if resource && resource.errors.empty?
        resource.reset_password_token = @reset_password_token
        @answers = resource.security_answers.sample(NUM_SECURITY_QUESTIONS_TO_CONFIRM)
      else
        flash[:error] = t('devise.passwords.invalid_token')
        redirect_to new_user_password_path
      end
    end

    def check
      resource.check_security_question_answers(answers_params.values)

      if resource.errors.empty?
        handle_correct_answers
      else
        handle_incorrect_answers
      end
    end

    protected

    def assign_resource
      @reset_password_token = reset_password_param
      self.resource = resource_class.with_reset_password_token(@reset_password_token)
    end

    # Return `true` if the attempts were exceeded and the user is being redirected, false otherwise.
    def check_attempts_exceeded
      if resource && resource.security_questions_attempts_exceeded?
        flash[:error] = t('errors.messages.max_security_questions_attempts') if is_flashing_format?
        redirect_to root_path
        true
      else
        false
      end
    end

    def handle_correct_answers
      resource.reset_security_questions_attempts
      resource.confirm_security_questions_answered
      resource.reset_password_token = @reset_password_token

      ::NewRelic::Agent.increment_metric('Custom/User/SecQuestionsAnswered')
      resource.log 'Authenticated Security Answers for Password Reset'

      flash[:success] = t('devise.passwords.choose_new_password')
      render 'devise/passwords/edit'
    end

    def handle_incorrect_answers
      resource.increase_security_questions_attempts
      return if check_attempts_exceeded

      flash[:error] = t('devise.security_questions.errors.wrong_answers') if is_flashing_format?
      redirect_to users_questions_confirm_path(reset_password_token: @reset_password_token)
    end

    private

    def questions_params
      params.require(:user).permit(security_answers_attributes: [:id, :security_question_id, :text])
    end

    def answers_params
      # NOTE: make more restrictive
      resource_params.require(:security_answers_attributes)
    end

    def reset_password_param
      if params.try(:[], :reset_password_token)
        params.require(:reset_password_token)
      else
        params.require(:user)[:reset_password_token]
      end
    end

    def user_valid?(user)
      user.update(questions_params)
    rescue ActiveRecord::RecordNotUnique => error
      user.security_answers.each do |answer|
        next unless answer.security_question_id == id_from_error(error)
        answer.errors[:security_question_id] << 'has already been taken'
      end

      false
    end

    def id_from_error(error)
      if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
        error.message.match(/Duplicate entry '\d+-\d+'/).to_s.split("'").
          last.split('-').first.to_i
      elsif ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
        error.message.match(/\(security_question_id, user_id\)=\(\d+, \d+\)/).
          to_s.split('=(').last.split(',').first.to_i
      end
    end
  end
end
