module Api
  module Verify
    class BaseController < ApplicationController
      skip_before_action :verify_authenticity_token

      before_action :confirm_two_factor_authenticated_for_api
      respond_to :json

      private

      def render_errors(errors, status: :bad_request)
        render json: { errors: errors }, status: status
      end

      def confirm_two_factor_authenticated_for_api
        return if user_authenticated_for_api?
        render_errors({ user: 'Unauthorized' }, status: :unauthorized)
      end

      def user_authenticated_for_api?
        user_fully_authenticated?
      end
    end
  end
end
