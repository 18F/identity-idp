
module Test
  class OidcTestController < ApplicationController

    def initialize
      @client_id = 'urn:gov:gsa:openidconnect:sp:test'
      super
    end

    def index
      @start_url = "#{test_oidc_auth_request_url}?ial=biometric-comparison-required"
    end


    def auth_result
      code = params[:code]
      if code
        token_response = token(code)
        access_token = token_response[:access_token]
        userinfo_response = userinfo(access_token)
        redirect_to('/')
      else
          redirect_to('/?error=access_denied')
      end
    end

    def auth_request()
      ial = prepare_step_up_flow(ial: params[:ial], aal: params[:aal])

      idp_url = authorization_url(
        ial: ial,
        aal: params[:aal],
        )

      Rails.logger.info("Redirecting to #{idp_url}")

      redirect_to(idp_url)
    end

    def logout()
      redirect_to('/')
    end

    def authorization_url(ial:, aal: nil)
      authorization_endpoint = '/openid_connect/authorize'
      request_params = {
        client_id: client_id,
        response_type: 'code',
        acr_values: acr_values(ial: ial, aal: aal),
        scope: scopes_for(ial),
        redirect_uri:  test_oidc_auth_result_url ,
        state: random_value,
        nonce: random_value,
        prompt: 'select_account',
        biometric_comparison_required: ial == 'biometric-comparison-required',
      }.compact.to_query

      "#{authorization_endpoint}?#{request_params}"
    end



    def prepare_step_up_flow(ial:, aal: nil)
      if ial == 'step-up'
        ial = '1'
      else
        ial = 'biometric-comparison-required'
      end
      ial
    end

    def scopes_for(ial)
      case ial
      when '0'
        'openid email social_security_number'
      when '1', nil
        'openid email'
      when '2', 'biometric-comparison-required'
        'openid email profile social_security_number phone address'
      else
        raise ArgumentError.new("Unexpected IAL: #{ial.inspect}")
      end
    end

    def acr_values(ial:, aal:)
      values = []

      values << {
        '0' => 'http://idmanagement.gov/ns/assurance/ial/0',
        nil => 'http://idmanagement.gov/ns/assurance/ial/1',
        '' => 'http://idmanagement.gov/ns/assurance/ial/1',
        '1' => 'http://idmanagement.gov/ns/assurance/ial/1',
        '2' => 'http://idmanagement.gov/ns/assurance/ial/2',
        'biometric-comparison-required' => 'http://idmanagement.gov/ns/assurance/ial/2',
      }[ial]

      values << {
        '2' => 'http://idmanagement.gov/ns/assurance/aal/2',
        '2-phishing_resistant' => 'http://idmanagement.gov/ns/assurance/aal/2?phishing_resistant=true',
        '2-hspd12' => 'http://idmanagement.gov/ns/assurance/aal/2?hspd12=true',
      }[aal]

      values.compact.join(' ')
    end

    def token(code)
      json Faraday.post(
        '/api/openid_connect/token',
        grant_type: 'authorization_code',
        code: code,
        client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
        client_assertion: client_assertion_jwt,
        ).body
    end

    def json(response)
      JSON.parse(response.to_s).with_indifferent_access
    end

    def random_value
      SecureRandom.hex
    end

    def maybe_redact_ssn(ssn)
      if config.redact_ssn?
        # redact all characters since they're all sensitive
        ssn = ssn&.gsub(/\d/, '#')
      end

      ssn
    end

    def client_assertion_jwt
      jwt_payload = {
        iss: client_id,
        sub: client_id,
        aud: openid_configuration[:token_endpoint],
        jti: random_value,
        nonce: random_value,
        exp: Time.now.to_i + 1000,
      }

      JWT.encode(jwt_payload, config.sp_private_key, 'RS256')
    end

    def userinfo(access_token)
      url = '/api/openid_connect/user_info'

      connection = Faraday.new(url: url, headers:{'Authorization' => "Bearer #{access_token}" })
      JSON.parse(connection.get('').body).with_indifferent_access
    end

    def client_id
      @client_id
    end
  end
end
