# encoding: utf-8
module SamlIdp
  class IdpController < ActionController::Base
    include SamlIdp::Controller

    unloadable unless Rails::VERSION::MAJOR >= 4
    protect_from_forgery
    before_action :validate_saml_request, only: [:new, :create]

    def new
      render template: "saml_idp/idp/new"
    end

    def show
      render xml: SamlIdp.metadata.signed
    end

    def create
      unless params[:email].blank? && params[:password].blank?
        person = idp_authenticate(params[:email], params[:password])
        if person.nil?
          @saml_idp_fail_msg = "Incorrect email or password."
        else
          @saml_response = idp_make_saml_response(person)
          render :template => "saml_idp/idp/saml_post", :layout => false
          return
        end
      end
      render :template => "saml_idp/idp/new"
    end

    def logout
      idp_logout
      @saml_response = idp_make_saml_response(nil)
      render :template => "saml_idp/idp/saml_post", :layout => false
    end

    def idp_logout
      raise NotImplementedError
    end
    private :idp_logout

    def idp_authenticate(email, password)
      raise NotImplementedError
    end
    protected :idp_authenticate

    def idp_make_saml_response(person)
      raise NotImplementedError
    end
    protected :idp_make_saml_response
  end
end
