require 'base64'
require 'cgi'
require 'net/https'

module PivCacService
  class << self
    RANDOM_HOSTNAME_BYTES = 2

    include Rails.application.routes.url_helpers

    def decode_token(token)
      token_present(token) &&
        token_decoded(token)
    end

    def piv_cac_service_link(nonce)
      if FeatureManagement.development_and_identity_pki_disabled?
        test_piv_cac_entry_url
      else
        uri = URI(randomize_uri(Figaro.env.piv_cac_service_url))
        # add the nonce
        uri.query = "nonce=#{CGI.escape(nonce)}"
        uri.to_s
      end
    end

    def piv_cac_verify_token_link
      Figaro.env.piv_cac_verify_token_url
    end

    private

    def emails_match_domains?(email_domains, supported_domains)
      partial_domains, exact_domains = supported_domains.partition { |domain| domain[0] == '.' }

      (email_domains & exact_domains).any? ||
        any_partial_domains_match?(email_domains, partial_domains)
    end

    # :reek:NestedIterators
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

      uri = URI(piv_cac_verify_token_link)
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(decode_request(uri, token))
      end
      decode_token_response(res)
    end

    def decode_request(uri, token)
      req = Net::HTTP::Post.new(uri, 'Authentication' => authenticate(token))
      req.form_data = { token: token }
      req
    end

    def authenticate(token)
      secret = Figaro.env.piv_cac_verify_token_secret
      return '' if secret.blank?
      nonce = SecureRandom.hex(10)
      hmac = Base64.urlsafe_encode64(
        OpenSSL::HMAC.digest('SHA256', secret, [token, nonce].join('+')),
      )
      "hmac :#{nonce}:#{hmac}"
    end

    def decode_token_response(res)
      return { 'error' => 'token.bad' } unless res.code.to_i == 200
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
