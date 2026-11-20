# frozen_string_literal: true

module FederatedProtocols
  class Saml
    # The AAL class refs Login.gov answers, including the legacy default. A requested value is an
    # AAL only when it is exactly one of these. A class ref is a URI and never contains whitespace,
    # so a value that merely contains one of them, such as two class refs run together inside one
    # element, names nothing here; the request's ACR string is built only from exact matches, so
    # nothing can be smuggled past the authorization checks into the space-separated string the
    # component parser later splits.
    AAL_AUTHN_CONTEXT_CLASSREFS = ::Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_AAL.keys.freeze

    def initialize(request)
      @request = request
    end

    def issuer
      request.service_provider&.identifier
    end

    def ial
      if ialmax_requested_with_authn_context_comparison?
        ::Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF
      else
        requested_ial_authn_context || default_ial_authn_context
      end
    end

    def requested_ial_authn_context
      (OpenidConnectAuthorizeForm::IALS_BY_PRIORITY & request.requested_authn_contexts).first
    end

    def aal
      request.requested_authn_contexts.find do |classref|
        AAL_AUTHN_CONTEXT_CLASSREFS.include?(classref)
      end
    end

    def acr_values
      [aal, ial].compact.join(' ')
    end

    def vtr
      nil
    end

    def requested_attributes
      @requested_attributes ||= SamlRequestedAttributesPresenter.new(
        service_provider: current_service_provider,
        ial: ial,
        authn_request_attribute_bundle: SamlRequestParser.new(request).requested_attributes,
      ).requested_attributes
    end

    def service_provider
      current_service_provider
    end

    private

    attr_reader :request

    def default_ial_authn_context
      if current_service_provider&.ial
        ::Saml::Idp::Constants::AUTHN_CONTEXT_IAL_TO_CLASSREF[current_service_provider.ial]
      else
        ::Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
      end
    end

    def current_service_provider
      return @current_service_provider if defined?(@current_service_provider)
      @current_service_provider = ServiceProvider.find_by(issuer: issuer)
    end

    ##
    # A ServiceProvider can request an IAL authn context with a mimimum context comparison . In this
    # case the IdP is expected to return a result with that IAL or a higher one.
    #
    # If a SP requests IAL1 with the mimium context comparison then the IdP can response with a
    # IAL2 response. In order for this to happen the following need to be true:
    #
    # - The service provider is authorized to make IAL2 requests
    # - The user has a verified account
    #
    # This methods checks that we are in a situation where the authn context comparison situation
    # described above exists and the SP requirements are met (the requirement that the user is
    # verified occurs as part of the IALMax functionality).
    #
    def ialmax_requested_with_authn_context_comparison?
      return unless (current_service_provider&.ial || 1) > 1

      acr_component_value = Component::AcrComponentValues.by_name[requested_ial_authn_context]
      return unless acr_component_value.present?

      !acr_component_value.requirements.include?(:identity_proofing) &&
        request.requested_authn_context_comparison == 'minimum'
    end
  end
end
