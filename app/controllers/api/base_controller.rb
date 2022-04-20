module Api
  class BaseController < ApplicationController
    respond_to :json

    SUCCESS = 'SUCCESS'.freeze
    ERROR = 'ERROR'.freeze

    def confirm_two_factor_authenticated_for_api
      return if user_fully_authenticated?
      render json: { error: 'user is not fully authenticated', status: ERROR }, status: 401
    end
  end
end
