module Api
  module Verify
    class BaseController < ApplicationController
      include RenderConditionConcern

      class_attribute :required_step

      check_or_render_not_found -> do
        if self.class.required_step.blank?
          raise NotImplementedError, 'Controller must define required_step'
        end
        IdentityConfig.store.idv_api_enabled_steps.include?(self.class.required_step)
      end
      before_action :confirm_two_factor_authenticated_for_api

      respond_to :json

      private

      def confirm_two_factor_authenticated_for_api
        return if user_fully_authenticated?
        render json: { error: 'user is not fully authenticated' }, status: :unauthorized
      end
    end
  end
end
