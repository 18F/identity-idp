module Api
  class BaseController < ApplicationController
    before_action :check_api_enabled
    before_action :confirm_two_factor_authenticated_for_api

    respond_to :json

    def check_api_enabled
      render_api_not_found unless IdentityConfig.store.idv_api_enabled
    end

    def confirm_two_factor_authenticated_for_api
      return if user_fully_authenticated?
      render json: { error: 'user is not fully authenticated' }, status: :unauthorized
    end

    def render_api_not_found
      render json: { error: "The page you were looking for doesn't exist" }, status: :not_found
    end
  end
end
