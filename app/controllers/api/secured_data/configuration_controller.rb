# frozen_string_literal: true

module Api
  module SecuredData
    class ConfigurationController < ApplicationController
      include RenderConditionConcern
      prepend_before_action :skip_session_load
      prepend_before_action :skip_session_expiration

      check_or_render_not_found -> { IdentityConfig.store.secured_data_api_enabled }

      def index
        render json: SecuredDataConfigurationPresenter.new.configuration
      end
    end
  end
end
