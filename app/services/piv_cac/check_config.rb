module PivCac
  class CheckConfig
    def self.call
      return unless Rails.env.production?

      url = URI.parse(Figaro.env.piv_cac_verify_token_url)
      return if url.scheme == 'https'

      message = "PIV/CAC configured without SSL: #{Figaro.env.piv_cac_verify_token_url}"
      Rails.logger.error { "#{message} - EXITING" }
      raise message
    end
  end
end
