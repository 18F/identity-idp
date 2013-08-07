# encoding: utf-8
module SamlIdp
  class IdpController < ActionController::Base
    include SamlIdp::Controller

    unloadable
    protect_from_forgery
    before_filter :validate_saml_request

    def new
      render :template => "saml_idp/idp/new"
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
