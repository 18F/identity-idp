class ExpiredLettersController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authorize

  def update
    count = ExpiredLetters.new.call
    analytics.track_event(Analytics::EXPIRED_LETTERS, event: :notifications, count: count)
    render plain: 'ok'
  end

  private

  def authorize
    return if auth_token == Figaro.env.expired_letters_auth_token
    head :unauthorized
  end

  def auth_token
    request.headers['X-API-AUTH-TOKEN']
  end
end
