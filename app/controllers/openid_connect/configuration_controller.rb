module OpenidConnect
  class ConfigurationController < ApplicationController
    def index
      expires_in 1.week, public: true

      render json: OpenidConnectConfigurationPresenter.new.configuration
    end
  end
end
