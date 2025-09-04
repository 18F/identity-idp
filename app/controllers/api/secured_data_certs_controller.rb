# frozen_string_literal: true

module Api
  class SecuredDataCertsController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :disable_caching

    JSON = SecuredDataApiCertsPresenter.new.certs.freeze

    def index
      expires_in 1.week, public: true

      render json: JSON
    end
  end
end
