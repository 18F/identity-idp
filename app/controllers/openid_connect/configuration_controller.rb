module OpenidConnect
  class ConfigurationController < ApplicationController
    def index
      render json: OpenidConnectConfigurationPresenter.new.configuration
    end
  end
end
