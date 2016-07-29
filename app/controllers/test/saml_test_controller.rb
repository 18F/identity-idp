require 'saml_idp_constants'
require 'saml_idp/logout_request_builder'
require './spec/support/saml_auth_helper'

module Test
  class SamlTestController < ApplicationController
    include SamlAuthHelper

    skip_before_action :verify_authenticity_token, only: [:decode_response, :decode_slo_request]

    def start
      request = OneLogin::RubySaml::Authrequest.new
      redirect_to(request.create(test_saml_settings, {}))
    end

    # rubocop:disable MethodLength
    # TODO(sbc): Refactor to address rubocop warnings
    def decode_response
      response = OneLogin::RubySaml::Response.new(
        params[:SAMLResponse],
        settings: test_saml_settings
      )

      # Ruby-saml only understands validation of Assertions. If it's
      # a LogoutRequest, just validate the signature.
      doc = Saml::XML::Document.parse(response.document.to_s)
      if doc.at_xpath('/samlp:Response', samlp: Saml::XML::Namespaces::PROTOCOL)
        is_valid = response.is_valid?
      elsif doc.at_xpath('/samlp:LogoutResponse', samlp: Saml::XML::Namespaces::PROTOCOL)
        begin
          is_valid = doc.valid_signature?(saml_cert)
        rescue
          is_valid = false
        end
      end

      render template: 'test/saml_test/decode_response.html.slim',
             locals: { is_valid: is_valid, response: response }
    end
    # rubocop:enable MethodLength

    # Method to handle IdP initiated logouts
    # rubocop:disable AbcSize, MethodLength
    # TODO(sbc): Refactor to address rubocop warning
    def decode_slo_request
      if params[:SAMLRequest]
        logout_request = OneLogin::RubySaml::SloLogoutrequest.new(params[:SAMLRequest])

        if logout_request.is_valid?
          logger.info "IdP initiated Logout for #{logout_request.name_id}"
          # Generate a response to the IdP.
          logout_request_id = logout_request.id
          logout_response = OneLogin::RubySaml::SloLogoutresponse.new
          saml_response = logout_response.create(
            test_saml_settings,
            logout_request_id,
            nil,
            RelayState: params[:RelayState]
          )
          redirect_to saml_response and return
        else
          response = logout_request.errors.to_s
          render template: 'test/saml_test/decode_response.html.slim',
                 locals: { is_valid: false, response: response }
        end
      elsif params[:SAMLResponse]
        decode_response
      end
    end
    # rubocop:enable AbcSize, MethodLength

    private

    def test_saml_settings
      sp1_saml_settings
    end
  end
end
