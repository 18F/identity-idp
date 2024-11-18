# frozen_string_literal: true

module PivCac
  class CheckConfig
    def self.call
      return unless Rails.env.production?

      url = URI.parse(IdentityConfig.store.piv_cac_verify_token_url)
      return if url.scheme == 'https'

      message = "piv_cac_verify_token_url configured without SSL: #{IdentityConfig.store.piv_cac_verify_token_url}"
      Rails.logger.error { "#{message} - EXITING" }
      NewRelic::Agent.notice_error("#{message} - EXITING")
      raise message
    end
  end
end
