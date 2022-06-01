module Api
  module Verify
    class BaseController < ApplicationController
      include RenderConditionConcern

      check_or_render_not_found -> do
        IdentityConfig.store.idv_api_enabled_steps.include?(required_step)
      end
      before_action :confirm_two_factor_authenticated_for_api

      respond_to :json

      private

      def confirm_two_factor_authenticated_for_api
        return if user_fully_authenticated?
        render json: { error: 'user is not fully authenticated' }, status: :unauthorized
      end

      def required_step
        raise NotImplementedError
      end
    end
  end
end
