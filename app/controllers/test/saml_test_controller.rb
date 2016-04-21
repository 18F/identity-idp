require 'saml_idp_constants'
require 'saml_idp/logout_request_builder'

module Test
  class SamlTestController < ApplicationController
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

      # Ruby-saml only understands validation of Assertions. If it's
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
      settings = OneLogin::RubySaml::Settings.new

      # SP settings
      settings.assertion_consumer_service_url = 'http://localhost:3000/test/saml/decode_assertion'
      settings.assertion_consumer_logout_service_url = 'http://localhost:3000/test/saml/decode_slo_request'
      settings.certificate = Rails.application.secrets.saml_cert
      settings.private_key = private_key
      settings.authn_context = Saml::Idp::Constants::LOA1_AUTHNCONTEXT_CLASSREF

      # SP + IdP Settings
      settings.issuer = 'https://upaya-dev.ngrok.io'
      settings.security[:logout_requests_signed] = true
      settings.security[:embed_sign] = true
      settings.security[:digest_method] = 'http://www.w3.org/2001/04/xmlenc#sha256'
      settings.security[:signature_method] = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'
      settings.name_identifier_format = 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
      settings.double_quote_xml_attribute_values = true
      # IdP setting
      settings.idp_sso_target_url = 'https://upaya-dev.ngrok.io/api/saml/auth'
      settings.idp_slo_target_url = 'https://upaya-dev.ngrok.io/api/saml/logout'
      settings.idp_cert_fingerprint = fingerprint

      settings
    end

    def private_key
      OpenSSL::PKey::RSA.new(
        File.read(Rails.root + 'config/saml.key.enc'),
        Rails.application.secrets.saml_passphrase
      ).to_pem
    end

    def fingerprint
      'F9:A3:9B:2F:8F:1C:E2:79:27:69:EB:32:ED:2A:D5:' \
      'A2:A7:58:5F:C0:74:8A:4A:03:D9:0F:77:A5:89:7F:F9:68'
    end
  end
end
