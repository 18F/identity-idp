# rubocop:disable Metrics/ModuleLength
module SamlIdpAuthConcern
  extend ActiveSupport::Concern

  included do
    # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :validate_saml_request, only: :auth
    before_action :validate_service_provider_and_authn_context, only: :auth
    before_action :store_saml_request, only: :auth
    # rubocop:enable Rails/LexicallyScopedActionFilter
  end

  private

  def validate_service_provider_and_authn_context
    @saml_request_validator = SamlRequestValidator.new

    @result = @saml_request_validator.call(
      service_provider: current_service_provider,
      authn_context: requested_authn_context,
      nameid_format: saml_request.name_id_format,
    )

    return if @result.success?

    analytics.track_event(Analytics::SAML_AUTH, @result.to_h)
    render 'saml_idp/auth/error', status: :bad_request
  end

  def store_saml_request
    # pp saml_request

    ServiceProviderRequestHandler.new(
      url: request_url,
      session: session,
      protocol_request: saml_request,
      protocol: FederatedProtocols::Saml,
    ).call
  end

  def requested_authn_context
    @requested_authn_context ||= saml_request.requested_authn_context || default_authn_context
  end

  def default_authn_context
    Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF
  end

  def link_identity_from_session_data
    IdentityLinker.new(current_user, current_issuer).link_identity(ial: ial_level)
  end

  def identity_needs_verification?
    loa3_requested? && current_user.decorate.identity_not_verified?
  end

  def ial_level
    loa3_requested? ? 3 : 1
  end

  def loa3_requested?
    requested_authn_context == Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF
  end

  def active_identity
    current_user.last_identity
  end

  def encode_authn_response(principal, opts)
    build_asserted_attributes(principal)
    super(principal, opts)
  end

  def attribute_asserter(principal)
    AttributeAsserter.new(
      user: principal,
      service_provider: current_service_provider,
      authn_request: saml_request,
      decrypted_pii: decrypted_pii,
    )
  end

  def decrypted_pii
    cacher = Pii::Cacher.new(current_user, user_session)
    cacher.fetch
  end

  def build_asserted_attributes(principal)
    asserter = attribute_asserter(principal)
    asserter.build
  end

  def saml_response
    encode_response(
      current_user,
      authn_context_classref: requested_authn_context,
      reference_id: active_identity.session_uuid,
      encryption: current_service_provider.encryption_opts,
      signature: saml_response_signature_options,
    )
  end

  # :reek:FeatureEnvy
  def saml_response_signature_options
    endpoint = SamlEndpoint.new(request)
    {
      x509_certificate: endpoint.x509_certificate,
      secret_key: endpoint.secret_key,
      cloudhsm_key_label: endpoint.cloudhsm_key_label,
    }
  end

  def current_service_provider
    @_sp ||= ServiceProvider.from_issuer(current_issuer)
  end

  def current_issuer
    @_issuer ||= saml_request.service_provider.identifier
  end

  def request_url
    # puts "Original URL: #{request.original_url}"
    url = URI.parse request.original_url
    query_params = parse_query_params url.query
    unless query_params['SAMLRequest']
      orig_request = saml_request.options[:get_params][:SAMLRequest]
      query_params['SAMLRequest'] = orig_request
    end

    url.query = query_hash_to_string(query_params)
    # puts "Modified URL: #{url.to_s}"
    url.to_s
  end

  # :reek:FeatureEnvy
  # :reek:TooManyStatements
  # rubocop:disable Metrics/MethodLength
  # Derived from https://github.com/postmodern/uri-query_params/blob/master/lib/uri/query_params/query_params.rb#L44-L65
  def parse_query_params(query_string)
    return {} unless query_string.presence

    query_params = {}

    query_string.split('&').each do |param|
      # skip empty params
      next if param.empty?

      name, value = param.split('=')
      value = if value
                CGI.unescape(value)
              else
                ''
              end

      query_params[name] = value
    end

    query_params
  end
  # rubocop:enable Metrics/MethodLength

  def query_hash_to_string(query_hash)
    query_string = query_hash.keys.map do |key|
      "#{key}=#{CGI.escape query_hash[key]}"
    end.join('&')
    query_string.presence
  end
end
# rubocop:enable Metrics/ModuleLength
