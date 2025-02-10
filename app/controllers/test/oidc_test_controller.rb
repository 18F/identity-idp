# frozen_string_literal: true

require './spec/support/oidc_auth_helper'
module Test
  class OidcTestController < ApplicationController
    include OidcAuthHelper

    FACIAL_MATCH_REQUIRED = 'facial-match-required'

    def initialize
      @client_id = 'urn:gov:gsa:openidconnect:sp:sinatra'
      super
    end

    def index
      # default to require
      @start_url_selfie = "#{test_oidc_auth_request_url}?ial=#{FACIAL_MATCH_REQUIRED}"
      @start_url_ial2 = "#{test_oidc_auth_request_url}?ial=2"
      @start_url_ial1 = "#{test_oidc_auth_request_url}?ial=1"
      update_service_provider
    end

    def auth_request
      ial = prepare_step_up_flow(ial: params[:ial])

      idp_url = authorization_url(
        ial: ial,
        aal: params[:aal],
      )

      Rails.logger.info("Redirecting to #{idp_url}")

      redirect_to(idp_url)
    end

    def auth_result
      redirect_to('/')
    end

    def logout
      redirect_to(logout_uri)
    end

    def authorization_url(ial:, aal: nil)
      authorization_endpoint = openid_configuration[:authorization_endpoint]
      params = ial2_params(
        client_id: client_id,
        acr_values: acr_values(ial: ial, aal: aal),
        facial_match_required: ial == FACIAL_MATCH_REQUIRED,
        state: random_value,
        nonce: random_value,
      )
      request_params = params.merge(
        scope: scopes_for(ial),
        redirect_uri: test_oidc_auth_result_url,
      ).compact.to_query
      "#{authorization_endpoint}?#{request_params}"
    end

    def prepare_step_up_flow(ial:)
      if ial == 'step-up'
        ial = '1'
      end
      ial
    end

    def scopes_for(ial)
      case ial
      when '0'
        'openid email social_security_number'
      when '1', nil
        'openid email'
      when '2', FACIAL_MATCH_REQUIRED
        'openid email profile social_security_number phone address'
      else
        raise ArgumentError.new("Unexpected IAL: #{ial.inspect}")
      end
    end

    def acr_values(ial:, aal:)
      ial_value = {
        '0' => 'http://idmanagement.gov/ns/assurance/ial/0',
        nil => 'http://idmanagement.gov/ns/assurance/ial/1',
        '' => 'http://idmanagement.gov/ns/assurance/ial/1',
        '1' => 'http://idmanagement.gov/ns/assurance/ial/1',
        '2' => 'http://idmanagement.gov/ns/assurance/ial/2',
        'facial-match-required' => 'http://idmanagement.gov/ns/assurance/ial/2',
      }[ial]
      aal_value = {
        '2' => 'http://idmanagement.gov/ns/assurance/aal/2',
        '2-phishing_resistant' => 'http://idmanagement.gov/ns/assurance/aal/2?phishing_resistant=true',
        '2-hspd12' => 'http://idmanagement.gov/ns/assurance/aal/2?hspd12=true',
      }[aal]
      [ial_value, aal_value].compact.join(' ')
    end

    def json(response)
      JSON.parse(response.to_s).with_indifferent_access
    end

    def random_value
      SecureRandom.hex
    end

    def client_id
      @client_id
    end

    private

    def logout_uri
      endpoint = openid_configuration[:end_session_endpoint]
      request_params = {
        client_id: client_id,
        post_logout_redirect_uri: '/',
        state: SecureRandom.hex,
      }.to_query

      "#{endpoint}?#{request_params}"
    end

    def openid_configuration
      @openid_configuration ||= OpenidConnectConfigurationPresenter.new.configuration
    end

    def idp_public_key
      @idp_public_key ||= load_idp_public_key
    end

    def load_idp_public_key
      keys = OpenidConnectCertsPresenter.new.certs[:keys]
      JSON::JWK.new(keys.first).to_key
    end

    def update_service_provider
      return @service_provider if defined?(@service_provider)
      @service_provider = ServiceProvider.find_by(issuer: client_id)
      # inject root url
      changed = false
      [test_oidc_logout_url, test_oidc_auth_result_url, root_url].each do |url|
        if @service_provider&.redirect_uris && !@service_provider.redirect_uris.include?(url)
          @service_provider.redirect_uris.append(url)
          changed = true
        end
      end
      @service_provider.save! if changed
    end
  end
end
