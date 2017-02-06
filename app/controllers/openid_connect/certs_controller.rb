module OpenidConnect
  class CertsController < ApplicationController
    def index
      expires_in 1.week, public: true

      render json: OpenidConnectCertsPresenter.new.certs
    end
  end
end
