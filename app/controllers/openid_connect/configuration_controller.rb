# frozen_string_literal: true

module OpenidConnect
  class ConfigurationController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :disable_caching

    def index
      expires_in 1.week, public: true

      render json: OpenidConnectConfigurationPresenter.new.configuration
    end
  end
end
