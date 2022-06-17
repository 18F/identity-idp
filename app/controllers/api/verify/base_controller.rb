module Api
  module Verify
    class BaseController < ApplicationController
      skip_before_action :verify_authenticity_token
      include RenderConditionConcern

      class_attribute :required_step

      def self.required_step
        NotImplementedError.new('Controller must define required_step')
      end

      check_or_render_not_found -> do
        required_step = self.class.required_step
        raise required_step if required_step.is_a?(NotImplementedError)
        !required_step || IdentityConfig.store.idv_api_enabled_steps.include?(required_step)
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
