module OpenidConnect
  class CertsController < ApplicationController
    skip_before_action :disable_caching

    def index
      expires_in 1.week, public: true

      render json: OpenidConnectCertsPresenter.new.certs
    end
  end
end
