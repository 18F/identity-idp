module PivCac
  class CheckConfig
    def self.call
      return unless Rails.env.production?

      url = URI.parse(Identity::Hostdata.settings.piv_cac_verify_token_url)
      return if url.scheme == 'https'

      # rubocop:disable Layout/LineLength
      message = "piv_cac_verify_token_url configured without SSL: #{Identity::Hostdata.settings.piv_cac_verify_token_url}"
      # rubocop:enable Layout/LineLength
      Rails.logger.error { "#{message} - EXITING" }
      NewRelic::Agent.notice_error("#{message} - EXITING")
      raise message
    end
  end
end
