module Api
  module Attempts
    class ConfigurationController < ApplicationController
      include RenderConditionConcern
      prepend_before_action :skip_session_load
      prepend_before_action :skip_session_expiration

      check_or_render_not_found -> { IdentityConfig.store.attempts_api_enabled }

      def index
        render json: AttemptsConfigurationPresenter.new.configuration
      end
    end
  end
end
