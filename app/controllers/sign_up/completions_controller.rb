module SignUp
  class CompletionsController < ApplicationController
    def show; end

    def update
      redirect_to session[:saml_request_url]
    end
  end
end
