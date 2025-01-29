# frozen_string_literal: true

module Api
  module Attempts
    class EventsController < ApplicationController
      include RenderConditionConcern
      check_or_render_not_found -> { IdentityConfig.store.attempts_api_enabled }

      prepend_before_action :skip_session_load
      prepend_before_action :skip_session_expiration

      def poll
        head :method_not_allowed
      end

      def status
        render json: {
          status: :disabled,
          reason: :not_yet_implemented,
        }
      end
    end
  end
end
