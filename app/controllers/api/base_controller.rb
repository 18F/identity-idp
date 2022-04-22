module Api
  class BaseController < ApplicationController
    respond_to :json

    def confirm_two_factor_authenticated_for_api
      return if user_fully_authenticated?
      render json: { error: 'user is not fully authenticated' },
             status: :unauthorized,

    end
  end
end
