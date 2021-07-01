module Risc
  class ConfigurationController < ApplicationController
    def index
      render json: RiscConfigurationPresenter.new.configuration
    end
  end
end
