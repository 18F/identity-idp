module Idv
  module InPerson
    class StateIdVerifyController < ApplicationController
      include RenderConditionConcern
      include UspsInPersonProofing
      include EffectiveUser
      include UspsInPersonProofing

      check_or_render_not_found -> { InPersonConfig.enabled? }

      before_action :confirm_authenticated_for_api

      def index
        validator = EnrollmentValidator.new
        results = validator.validate(
          params.permit(*EnrollmentValidator::SUPPORTED_FIELDS).to_h,
        )

        render json: { success: true, data: results }
      end

      def confirm_authenticated_for_api
        render json: { success: false }, status: :unauthorized if !effective_user
      end
    end
  end
end
