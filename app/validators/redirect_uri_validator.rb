module RedirectUriValidator
  extend ActiveSupport::Concern

  included do
    attr_reader :redirect_uri, :post_logout_redirect_uri, :service_provider

    validate :allowed_redirect_uri
  end

  private

  def allowed_redirect_uri
    return unless service_provider.present?
    return if any_registered_sp_redirect_uris_identical_to_the_requested_uri?

    errors.add(
      :redirect_uri, t('openid_connect.authorization.errors.redirect_uri_no_match'),
      type: :redirect_uri_no_match
    )
  end

  def any_registered_sp_redirect_uris_identical_to_the_requested_uri?
    service_provider.redirect_uris.any? do |sp_redirect_uri|
      parsed_sp_redirect_uri = URI.parse(sp_redirect_uri)

      parsed_sp_redirect_uri == parsed_redirect_uri
    end
  rescue ArgumentError, URI::InvalidURIError
    errors.add(
      :redirect_uri, t('openid_connect.authorization.errors.redirect_uri_invalid'),
      type: :redirect_uri_invalid
    )
  end

  def parsed_redirect_uri
    requested_uri = post_logout_redirect_uri || redirect_uri
    URI.parse(requested_uri)
  end
end
