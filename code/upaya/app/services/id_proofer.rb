require 'exceptions'

class IdProofer
  def initialize(response)
    @response = response
    @response_code = response.code.to_i
    @body = response.body.present? ? JSON.parse(response.body) : {}
    process_response_status
  end

  def check_quiz_status
    return true if quiz_status == 'NOT_STARTED' || quiz_status == 'NOT_ENOUGH_QUESTIONS'

    yield :inprogress
  end

  def register_user
    return true if status == 'REGISTERED'

    if @response_code == 201
      yield action_from_registration_status(status)
    else
      yield action_from_error_code(error_code)
    end
  end

  def process_question
    return question if question.present?

    yield action_from_error_code(error_code)
  end

  def process_answer
    yield action_from_quiz_status(quiz_status)
  end

  def status
    @status ||= @body['status']
  end

  private

  def process_response_status
    Rails.logger.info "IdPaaS returned a #{@response_code} with body: #{@body}"

    fail Exceptions::IdPaasDown if @response_code.between?(500, 599) || @body == {}
  end

  def error_code
    @error_code = @body['errorCode']
  end

  def quiz_status
    @quiz_status ||= @body['quizStatus']
  end

  def question
    @question ||= @body['question']
  end

  def action_from_quiz_status(status)
    return quiz_status_to_action.fetch(status) if quiz_status_to_action.key?(status)

    action_from_error_code(error_code)
  end

  def quiz_status_to_action
    {
      'STARTED' => :started,
      'FAILED' => :fail,
      'TIMED_OUT' => :timed_out,
      'PASSED' => :passed
    }
  end

  def action_from_registration_status(status)
    registration_status_to_action.fetch(status)
  end

  def registration_status_to_action
    {
      'FAILED' => :hardfail,
      'ID_PROOFED' => :confirm_user_needs_idv
    }
  end

  def action_from_error_code(error_code)
    error_code_to_action.fetch(error_code)
  end

  def error_code_to_action
    {
      'NOT_ENOUGH_QUESTIONS' => :fail,
      'REGISTRATION_LOCKED' => :hardfail,
      'TOKEN_LOCKED' => :hardfail,
      'USER_ALREADY_FAILED' => :hardfail,
      'INVALID_APP_ID' => :idpaas_down,
      'USER_NOT_REGISTERED' => :index,
      'QUESTION_ALREADY_ANSWERED' => :question
    }
  end
end
