require 'sinatra/base'

class FakeIdpaas < Sinatra::Base
  get '/idpaas/user/:user_uuid/question/' do
    json_response 200, {
      question: {
        questionId: '6c354be7-6d0f-46ab-8407-96624a362f17',
        text: 'What was the priority date for your U.S. immigrant visa?',
        answers: [
          {
            key: 1,
            text: '06/01/2015'
          },
          {
            key: 2,
            text: '10/24/2014'
          },
          {
            key: 3,
            text: '08/15/2014'
          },
          {
            key: 4,
            text: '01/26/2015'
          },
          {
            key: 5,
            text: 'NONE OF THE ABOVE'
          }
        ],
        helpMessage: 'This is the help message',
        helpImageUrl: 'http://localhost:8080/idpaas/help-image/'\
          '22619919-2adb-5825-1cf4-06e1d4a9e11b.jpg'
      }
    }.to_json
  end

  get '/idpaas/user/:user_uuid/' do
    json_response 200, { status: 'FAILED' }.to_json
  end

  post '/idpaas/user/:user_uuid/' do
    json_response 201, { status: 'REGISTERED' }.to_json
  end

  post '/idpaas/user/:user_uuid/question/' do
    request.body.rewind

    key = JSON.parse(request.body.read)['key']

    json_response 200, { quizStatus: quiz_status(key) }.to_json
  end

  get '/idpaas/user/:user_uuid/quiz-status/' do
    json_response 200, { quizStatus: 'NOT_STARTED' }.to_json
  end

  private

  def json_response(response_code, payload)
    content_type :json
    status response_code
    payload
  end

  def quiz_status(key)
    key_to_result.fetch(key)
  end

  def key_to_result
    {
      1 => 'STARTED',
      2 => 'NOT_ENOUGH_QUESTIONS',
      3 => 'FAILED',
      4 => 'NOT_STARTED'
    }
  end
end
