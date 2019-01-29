require 'saml_idp_constants'
require 'saml_idp/logout_request_builder'
require './spec/support/saml_auth_helper'

module Test
  class SamlTestController < ApplicationController
    include SamlAuthHelper

    skip_before_action :verify_authenticity_token, only: %i[decode_response decode_slo_request]

    def start
      request = OneLogin::RubySaml::Authrequest.new
      redirect_to(request.create(test_saml_settings, {}))
    end

    def decode_response
      res = SloResponseDecoder.new(params, test_saml_settings)

      render_template_for(true, res.response)
    end

    # Method to handle IdP initiated logouts
    def decode_slo_request
      slo = SingleLogoutService.new(params, test_saml_settings)

      return decode_response if slo.response?

      return unless slo.valid_request?

      slo.log_event
      redirect_to slo.slo_response
    end

    private

    def test_saml_settings
      sp1_saml_settings
    end

    def render_template_for(validity, response)
      render(
        template: 'test/saml_test/decode_response.html.slim',
        locals: { is_valid: validity, response: response },
      )
    end
  end
end
