require 'base64'
require 'cgi'

module PivCacService
  class << self
    RANDOM_HOSTNAME_BYTES = 2

    include Rails.application.routes.url_helpers

    def decode_token(token)
      token_present(token) &&
        token_decoded(token)
    end

    def piv_cac_service_link(nonce:, redirect_uri:)
      uri = if FeatureManagement.development_and_identity_pki_disabled?
              URI(test_piv_cac_entry_url)
            else
              URI(randomize_uri(AppConfig.env.piv_cac_service_url))
            end
      # add the nonce and redirect uri
      uri.query = { nonce: nonce, redirect_uri: redirect_uri }.to_query
      uri.to_s
    end

    def piv_cac_verify_token_link
      AppConfig.env.piv_cac_verify_token_url
    end

    private

    def emails_match_domains?(email_domains, supported_domains)
      partial_domains, exact_domains = supported_domains.partition { |domain| domain[0] == '.' }

      (email_domains & exact_domains).any? ||
        any_partial_domains_match?(email_domains, partial_domains)
    end

    def any_partial_domains_match?(givens, matchers)
      givens.any? do |given|
        matchers.any? { |matcher| given.end_with?(matcher) }
      end
    end

    def randomize_uri(uri)
      # we only support {random}, so we're going for performance here
      uri.gsub('{random}') { |_| SecureRandom.hex(RANDOM_HOSTNAME_BYTES) }
    end

    def token_present(token)
      raise ArgumentError, 'token missing' if token.blank?
      true
    end

    def token_decoded(token)
      return decode_test_token(token) if token.start_with?('TEST:')
      return { 'error' => 'service.disabled' } if FeatureManagement.identity_pki_disabled?
      res = token_response(token)
      decode_token_response(res)
    end

    def token_response(token)
      # Assume ssl is off unless verify_token_uri uses https
      ssl_config = false
      if verify_token_uri.scheme == 'https'
        ssl_config = { verify: !FeatureManagement.identity_pki_local_dev? }
      end

      Faraday.new(ssl: ssl_config).post(
        verify_token_uri,
        URI.encode_www_form({ token: token }),
        Authentication: authenticate(token),
      )
    end

    def verify_token_uri
      URI(piv_cac_verify_token_link)
    end

    def authenticate(token)
      secret = AppConfig.env.piv_cac_verify_token_secret
      return '' if secret.blank?
      nonce = SecureRandom.hex(10)
      hmac = Base64.urlsafe_encode64(
        OpenSSL::HMAC.digest('SHA256', secret, [token, nonce].join('+')),
      )
      "hmac :#{nonce}:#{hmac}"
    end

    def decode_token_response(res)
      return { 'error' => 'token.bad' } unless res.status.to_i == 200
      JSON.parse(res.body)
    rescue JSON::JSONError
      { 'error' => 'token.bad' }
    end

    def decode_test_token(token)
      if FeatureManagement.development_and_identity_pki_disabled?
        JSON.parse(token[5..-1])
      else
        { 'error' => 'token.bad' }
      end
    end
  end
end
