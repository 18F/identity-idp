module IdpaasResponsesHelper
  PREFIX = "#{Figaro.env.idv_url}/user/".tr('/', '\/')
  UUID_REGEX = /.{8}-.{4}-.{4}-.{4}-.{12}/
  USER_REGEX = %r{#{PREFIX}#{UUID_REGEX}\/$}
  USER_QUIZ_STATUS_REGEX = %r{#{PREFIX}#{UUID_REGEX}\/quiz-status\/$}
  QUESTION_REGEX = %r{#{PREFIX}#{UUID_REGEX}\/question\/$}

  # Check user status ------------------------------------------------------- #
  # GET https://idpaas-test.18f.gov/idpaas/user/uuid/
  # Responses return 200 HTTP status code
  # Returns: {"status":"SOME_STATUS"}
  # Where SOME_STATUS can be NOT_REGISTERED, REGISTERED, FAILED, ID_PROOFED

  # Register user ------------------------------------------------------- #
  # POST https://idpaas-test.18f.gov/idpaas/user/uuid/
  # Body example: { "appID":"externalapp_dm_30a", "token":"c9a1e2bd-51ef-46f7-acd7-a8a5f4630722" }
  # Responses below return 201 HTTP status code

  def registered_response
    { status: 'REGISTERED' }.to_json
  end

  def failed_response
    { status: 'FAILED' }.to_json
  end

  def id_proofed_response
    { status: 'ID_PROOFED' }.to_json
  end

  # Responses below return 403 HTTP status code

  def registration_locked_response
    { statusCode: 403,
      errorCode: 'REGISTRATION_LOCKED',
      message: 'The registration for this account has been locked.' }.to_json
  end

  def token_locked_response
    { statusCode: 403,
      errorCode: 'TOKEN_LOCKED',
      message: 'The token {0} has already passed ID-Proofing for UUID {1}.' }.to_json
  end

  def invalid_app_id_response
    { statusCode: 403,
      errorCode: 'INVALID_APP_ID',
      message: 'The appId is invalid.' }.to_json
  end

  # ------------------------------------------------------------------------- #

  # Get questions for a registered user (assuming the registration was checked first)
  # GET https://idpaas-test.18f.gov/idpaas/user/uuid/question/
  # Responses below return HTTP 200 status code

  def question_response
    { question: question_hash }.to_json
  end

  def response_without_help
    { question:
      { questionId: 'unique_id',
        text: 'What is the ZIP code of the address where you plan to live in the U.S.?',
        answers: [
          { key: 1, text: '21005' },
          { key: 2, text: '21045' },
          { key: 3, text: '21917' },
          { key: 4, text: '21802' },
          { key: 5, text: 'NONE OF THE ABOVE' }
        ] } }.to_json
  end

  def response_without_help_with_nulls
    { question:
        { questionId: 'unique_id',
          text: 'What is the ZIP code of the address where you plan to live in the U.S.?',
          answers: [
            { key: 1, text: '21005' },
            { key: 2, text: '21045' },
            { key: 3, text: '21917' },
            { key: 4, text: '21802' },
            { key: 5, text: 'NONE OF THE ABOVE' }
          ],
          helpMessage: nil,
          helpUuid: nil,
          helpImageUrl: nil } }.to_json
  end

  # Responses below return HTTP 404 status code

  def not_enough_questions_response
    { statusCode: 404,
      errorCode: 'NOT_ENOUGH_QUESTIONS',
      message: 'Not enough questions could be generated for the quiz.' }.to_json
  end

  def user_not_registered_response
    { statusCode: 404,
      errorCode: 'USER_NOT_REGISTERED',
      message: 'The user is not registered.' }.to_json
  end

  # Responses below return HTTP 403 status code

  def user_already_failed_response
    { statusCode: 403,
      errorCode: 'USER_ALREADY_FAILED',
      message: 'The user has already failed ID Proofing previously.' }.to_json
  end

  # ------------------------------------------------------------------------- #

  # Submit a user's answer to a question
  # POST https://idpaas-test.18f.gov/idpaas/user/uuid/question/
  # Body example: { "questionId":"eaef8225-0eed-4cde-817b-f1850302b7bc", "key":1 }
  # Responses below return HTTP 200 status code

  def started_quiz_response
    { quizStatus: 'STARTED' }.to_json
  end

  # You should not see this. If you do, please send IdPaaS all interactions
  # happening on the given {UUID}
  def stopped_quiz_response
    { quizStatus: 'STOPPED' }.to_json
  end

  def timed_out_quiz_response
    { quizStatus: 'TIMED_OUT' }.to_json
  end

  def failed_quiz_response
    { quizStatus: 'FAILED' }.to_json
  end

  def passed_quiz_response
    { quizStatus: 'PASSED' }.to_json
  end

  # Responses below return HTTP 404 status code

  # Returned when answering a question with a questionId that was not
  # appropriate for the quiz. This is a rare occurrence, and occurs when
  # a new quiz attempt got started for the UUID between the time when
  # the question was sent out and that question is actually being answered.
  # If you are seeing this, contact IdPaaS. There could be multiple IdProofing
  # sessions being attempted.
  def question_not_found_response
    { statusCode: 404,
      errorCode: 'QUESTION_NOT_FOUND',
      message: 'The question could not be found for the user.' }.to_json
  end

  # Returned when answering a question, but the quiz itself is no londer valid.
  # This is a rare occurrence. If you are seeing this, contact IdPaaS.
  # There could be multiple IdProofing sessions being attempted.
  def quiz_not_started_response
    { statusCode: 404,
      errorCode: 'QUIZ_NOT_STARTED',
      message: 'A new quiz has not been started for the user.' }.to_json
  end

  # Responses below return HTTP 403 status code

  def question_already_answered_response
    { statusCode: 403,
      errorCode: 'QUESTION_ALREADY_ANSWERED',
      message: 'The question has already been answered.' }.to_json
  end

  # ------------------------------------------------------------------------- #

  # Get quiz status for a user (assuming the registration was checked first)
  # GET https://idpaas-test.18f.gov/idpaas/user/uuid/quiz-status/
  # Responses below return HTTP 200 status code

  def not_started
    { quizStatus: 'NOT_STARTED' }.to_json
  end

  def started
    { quizStatus: 'STARTED' }.to_json
  end

  def not_enough_questions
    { quizStatus: 'NOT_ENOUGH_QUESTIONS' }.to_json
  end

  def stopped
    { quizStatus: 'STOPPED' }.to_json
  end

  def timed_out
    { quizStatus: 'TIMED_OUT' }.to_json
  end

  def failed
    { quizStatus: 'FAILED' }.to_json
  end

  # ------------------------------------------------------------------------- #

  def stub_quiz_not_started
    stub_request(:get, USER_QUIZ_STATUS_REGEX).
      to_return(status: 200, body: not_started, headers: {})
  end

  def stub_registration
    stub_request(:post, USER_REGEX).
      to_return(status: 201, body: registered_response, headers: {})
  end

  private

  def question_hash
    { questionId: '6c354be7-6d0f-46ab-8407-96624a362f17',
      text: 'What was the priority date for your U.S. immigrant visa?',
      answers: answers_hash,
      externalHelpImageUrl: 'http://i.imgur.com/uNFNaKI.png',
      helpMessage: 'The text is right there',
      helpImageUrl: 'http://localhost:8080/idpaas/help-image/85c7a266-868e-433a-95d1-'\
        '6c0243734ff5.png' }
  end

  def answers_hash
    [{ key: 1, text: '06/01/2015' },
     { key: 2, text: '10/24/2014' },
     { key: 3, text: '08/15/2014' },
     { key: 4, text: '01/26/2015' },
     { key: 5, text: 'NONE OF THE ABOVE' }]
  end
end
