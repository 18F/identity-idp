# frozen_string_literal: true

module Risc
  class ConfigurationController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration

    def index
      render json: RiscConfigurationPresenter.new.configuration
    end
  end
end
