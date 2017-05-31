class OpenidConnectRedirector
  include ActionView::Helpers::TranslationHelper

  def self.from_request_url(request_url)
    params = URIService.params(request_url)

    new(
      redirect_uri: params[:redirect_uri],
      service_provider: ServiceProvider.from_issuer(params[:client_id]),
      state: params[:state]
    )
  end

  def initialize(redirect_uri:, service_provider:, state:, errors: nil)
    @redirect_uri = redirect_uri
    @service_provider = service_provider
    @state = state
    @errors = errors
  end

  def validate
    validate_redirect_uri
    validate_redirect_uri_matches_sp_redirect_uri
  end

  def success_redirect_uri(code:)
    URIService.add_params(validated_input_redirect_uri, code: code, state: state)
  end

  def decline_redirect_uri
    URIService.add_params(
      validated_input_redirect_uri,
      error: 'access_denied',
      state: state
    )
  end

  def error_redirect_uri
    URIService.add_params(
      validated_input_redirect_uri,
      error: 'invalid_request',
      error_description: errors.full_messages.join(' '),
      state: state
    )
  end

  private

  attr_reader :redirect_uri, :service_provider, :state, :errors

  def validate_redirect_uri
    _uri = URI(redirect_uri)
  rescue ArgumentError, URI::InvalidURIError
    errors.add(:redirect_uri, t('openid_connect.authorization.errors.redirect_uri_invalid'))
  end

  def validate_redirect_uri_matches_sp_redirect_uri
    return if redirect_uri_matches_sp_redirect_uri?
    errors.add(:redirect_uri, t('openid_connect.authorization.errors.redirect_uri_no_match'))
  end

  def redirect_uri_matches_sp_redirect_uri?
    redirect_uri.present? &&
      service_provider.active? &&
      redirect_uri.start_with?(sp_redirect_uri)
  end

  def validated_input_redirect_uri
    redirect_uri if redirect_uri_matches_sp_redirect_uri?
  end

  def sp_redirect_uri
    service_provider.redirect_uri
  end
end
