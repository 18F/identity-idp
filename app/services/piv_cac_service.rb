require 'cgi'
require 'net/https'

module PivCacService
  class << self
    include Rails.application.routes.url_helpers

    def decode_token(token)
      token_present(token) &&
        token_decoded(token)
    end

    def piv_cac_service_link(nonce)
      if FeatureManagement.development_and_piv_cac_entry_enabled?
        test_piv_cac_entry_url
      else
        uri = URI(Figaro.env.piv_cac_service_url)
        # add the nonce
        uri.query = "nonce=#{CGI.escape(nonce)}"
        uri.to_s
      end
    end

    def piv_cac_verify_token_link
      Figaro.env.piv_cac_verify_token_url
    end

    def piv_cac_available_for_agency?(agency)
      return if agency.blank?
      return unless FeatureManagement.piv_cac_enabled?
      @piv_cac_agencies ||= begin
        piv_cac_agencies = Figaro.env.piv_cac_agencies || '[]'
        JSON.parse(piv_cac_agencies)
      end

      @piv_cac_agencies.include?(agency)
    end

    private

    # Only used in tests
    def reset_piv_cac_avaialable_agencies
      @piv_cac_agencies = nil
    end

    def token_present(token)
      raise ArgumentError, 'token missing' if token.blank?
      true
    end

    def token_decoded(token)
      return decode_test_token(token) if token.start_with?('TEST:')

      return { 'error' => 'service.disabled' } if FeatureManagement.identity_pki_disabled?

      uri = URI(piv_cac_verify_token_link)
      res = Net::HTTP.post_form(uri, token: token)
      decode_token_response(res)
    end

    def decode_token_response(res)
      return { 'error' => 'token.bad' } unless res.code.to_i == 200
      result = res.body
      JSON.parse(result)
    rescue JSON::JSONError
      { 'error' => 'token.bad' }
    end

    def decode_test_token(token)
      if FeatureManagement.development_and_piv_cac_entry_enabled?
        JSON.parse(token[5..-1])
      else
        { 'error' => 'token.bad' }
      end
    end
  end
end
