require 'saml_idp_constants'
require 'saml_idp/logout_request_builder'

module Test
  # SamlTestController is a simple smoketest for the SAML functionality in ICAM.
  #
  # It produces a SAML AuthNRequest to the ICAM saml auth endpoint and expects
  # a valid assertion to be generated using the test certificate.
  class SamlTestController < ApplicationController
    # Disable CSRF on API endpoints for POST binding.
    skip_before_action :verify_authenticity_token, only: [:decode_response, :decode_slo_request]

    def start
      request = OneLogin::RubySaml::Authrequest.new
      redirect_to(request.create(saml_settings,
                                 {},
                                 key: Rails.application.secrets.saml_client_private_key,
                                 algorithm: :sha256))
    end

    # rubocop:disable AbcSize, MethodLength
    def logout
      # Create LogoutRequest.
      signature_opts = {
        cert: File.read("#{Rails.root}/certs/saml_client_cert.crt"),
        key: Rails.application.secrets.saml_client_private_key,
        signature_alg: 'rsa-sha256',
        digest_alg: 'sha256'
      }

      logout_request_builder = SamlIdp::LogoutRequestBuilder.new(
        "_#{UUID.generate}", # response_id
        saml_settings.issuer,
        saml_settings.idp_slo_target_url,
        UUID.generate,       # name_id
        'bogus_fuzzy_lambs', # name_qualifier
        UUID.generate,       # session_index
        signature_opts)

      render template: 'saml_idp/shared/saml_post_binding.html.slim',
             locals: {
               action_url: '/api/saml/logout',
               message: Base64.encode64(logout_request_builder.build.to_xml),
               type: :SAMLRequest },
             layout: false
    end
    # rubocop:enable AbcSize, MethodLength

    # rubocop:disable AbcSize, MethodLength
    def decode_response
      response = OneLogin::RubySaml::Response.new(
        Base64.decode64(params[:SAMLResponse]),
        private_key: saml_settings.private_key,
        private_key_password: ''
      )
      response.settings = saml_settings

      # TODO(awong): Ruby-saml only understands validation of Assertions. If it's
      # a LogoutRequest, just validate the signature.
      doc = Saml::XML::Document.parse(response.document.to_s)
      if doc.at_xpath('/samlp:Response', samlp: Saml::XML::Namespaces::PROTOCOL)
        is_valid = response.is_valid?
      elsif doc.at_xpath('/samlp:LogoutResponse', samlp: Saml::XML::Namespaces::PROTOCOL)
        begin
          is_valid = doc.valid_signature?(Rails.application.secrets.saml_cert)
        rescue
          is_valid = false
        end
      end

      render template: 'test/saml_test/decode_response.html.slim',
             locals: { is_valid: is_valid, response: response }
    end
    # rubocop:enable AbcSize, MethodLength

    # Method to handle IdP initiated logouts
    # rubocop:disable AbcSize, MethodLength
    def decode_slo_request
      if params[:SAMLRequest]
        logout_request = OneLogin::RubySaml::SloLogoutrequest.new(params[:SAMLRequest])

        doc = Saml::XML::Document.parse(logout_request.document.to_s)
        is_valid = doc.valid_signature?(Rails.application.secrets.saml_cert)

        if is_valid
          logger.info "IdP initiated Logout for #{logout_request.name_id}"
          # Generate a response to the IdP.
          logout_request_id = logout_request.id
          logout_response = OneLogin::RubySaml::SloLogoutresponse.new
          saml_response = logout_response.create(
            saml_settings,
            logout_request_id,
            nil,
            RelayState: params[:RelayState]
          )
          redirect_to saml_response and return
        else
          response = doc.errors.to_s
          render template: 'test/saml_test/decode_response.html.slim',
                 locals: { is_valid: is_valid, response: response }
        end
      elsif params[:SAMLResponse]
        decode_response
      end
    end
    # rubocop:enable AbcSize, MethodLength

    private

    def saml_settings
      return SamlAuthHelper.sp1_saml_settings.dup if params[:sp] == 'elis'
      SamlAuthHelper.sp2_saml_settings.dup
    end
  end
end