module RedirectUriValidator
  extend ActiveSupport::Concern

  included do
    attr_reader :redirect_uri, :post_logout_redirect_uri, :service_provider

    validate :allowed_redirect_uri
  end

  private

  def allowed_redirect_uri
    return if any_registered_sp_redirect_uris_identical_to_the_requested_uri?

    errors.add(:redirect_uri, t('openid_connect.authorization.errors.redirect_uri_no_match'))
  end

  def any_registered_sp_redirect_uris_identical_to_the_requested_uri?
    service_provider.redirect_uris.any? do |sp_redirect_uri|
      parsed_sp_redirect_uri = URI.parse(sp_redirect_uri)

      parsed_sp_redirect_uri == parsed_redirect_uri ||
        matches_localhost_in_test?(parsed_sp_redirect_uri)
    end
  rescue ArgumentError, URI::InvalidURIError
    errors.add(:redirect_uri, t('openid_connect.authorization.errors.redirect_uri_invalid'))
  end

  def parsed_redirect_uri
    requested_uri = post_logout_redirect_uri || redirect_uri
    URI.parse(requested_uri)
  end

  def matches_localhost_in_test?(parsed_sp_redirect_uri)
    return false unless Rails.env.test?
    parsed_redirect_uri.host == '127.0.0.1' &&
      parsed_redirect_uri.path == parsed_sp_redirect_uri.path
  end
end
