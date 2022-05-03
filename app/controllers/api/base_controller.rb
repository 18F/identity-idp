module Api
  class BaseController < ApplicationController
    include RenderConditionConcern

    check_or_render_not_found -> { FeatureManagement.idv_api_enabled? }
    before_action :confirm_two_factor_authenticated_for_api

    respond_to :json

    def confirm_two_factor_authenticated_for_api
      return if user_fully_authenticated?
      render json: { error: 'user is not fully authenticated' }, status: :unauthorized
    end
  end
end
