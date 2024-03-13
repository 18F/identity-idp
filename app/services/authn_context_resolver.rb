class AuthnContextResolver
  attr_reader :service_provider, :vtr, :acr_values

  def initialize(service_provider:, vtr:, acr_values:)
    @service_provider = service_provider
    @vtr = vtr
    @acr_values = acr_values
  end

  def resolve
    if vtr.present?
      vot_parser_result
    else
      acr_result_with_sp_defaults
    end
  end

  private

  def vot_parser_result
    @vot_result = Vot::Parser.new(
      vector_of_trust: vtr&.first,
      acr_values: acr_values,
    ).parse
  end

  def acr_result_with_sp_defaults
    result_with_sp_aal_defaults(
      result_with_sp_ial_defaults(
        vot_parser_result,
      ),
    )
  end

  def result_with_sp_aal_defaults(result)
    if acr_aal_component_values.any?
      result
    elsif service_provider&.default_aal.to_i == 2
      result.with(aal2?: true)
    elsif service_provider&.default_aal.to_i >= 3
      result.with(aal2?: true, phishing_resistant?: true)
    else
      result
    end
  end

  def result_with_sp_ial_defaults(result)
    if acr_ial_component_values.any?
      result
    elsif service_provider&.ial.to_i >= 2
      result.with(identity_proofing?: true, aal2?: true)
    else
      result
    end
  end

  def acr_aal_component_values
    vot_parser_result.component_values.filter do |component_value|
      component_value.name.include?('aal') ||
        component_value.name == Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF
    end
  end

  def acr_ial_component_values
    vot_parser_result.component_values.filter do |component_value|
      component_value.name.include?('ial') || component_value.name.include?('loa')
    end
  end
end
