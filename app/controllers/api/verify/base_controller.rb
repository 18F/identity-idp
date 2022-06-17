module Api
  module Verify
    class BaseController < ApplicationController
      skip_before_action :verify_authenticity_token
      include RenderConditionConcern

      class_attribute :required_step

      check_or_render_not_found -> do
        if self.class.required_step.blank?
          raise NotImplementedError, 'Controller must define required_step'
        end
        IdentityConfig.store.idv_api_enabled_steps.include?(self.class.required_step)
      end

      def render_errors(error_or_errors, status: :bad_request)
        errors = error_or_errors.instance_of?(Hash) ? error_or_errors : Array(error_or_errors)
        render json: { errors: errors }, status: status
      end

      before_action :confirm_two_factor_authenticated_for_api
      respond_to :json

      private

      def confirm_two_factor_authenticated_for_api
        return if user_authenticated_for_api?
        render json: { error: 'user is not fully authenticated' }, status: :unauthorized
      end

      def user_authenticated_for_api?
        user_fully_authenticated?
      end
    end
  end
end
