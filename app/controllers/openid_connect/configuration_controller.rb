module OpenidConnect
  class ConfigurationController < ApplicationController
    skip_before_action :disable_caching

    def index
      expires_in 1.week, public: true

      render json: OpenidConnectConfigurationPresenter.new.configuration
    end
  end
end
