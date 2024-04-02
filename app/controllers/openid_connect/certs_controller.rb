# frozen_string_literal: true

module OpenidConnect
  class CertsController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :disable_caching

    def index
      expires_in 1.week, public: true

      render json: OpenidConnectCertsPresenter.new.certs
    end
  end
end
