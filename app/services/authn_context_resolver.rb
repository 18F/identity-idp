class AuthnContextResolver
  attr_reader :service_provider, :vtr, :acr_values

  def initialize(service_provider:, vtr:, acr_values:)
    @service_provider = service_provider
    @vtr = vtr
    @acr_values = acr_values
  end

  def resolve
    if vtr.present?
      vot_result
    else
      acr_result_with_sp_defaults
    end
  end

  private

  def vot_result
    return nil if vtr.blank?

    @vot_result = Vot::Parser.new(
      JSON.parse(vtr).first,
    ).parse
  end

  def acr_result_with_sp_defaults
    result_with_sp_aal_defaults(
      result_with_sp_ial_defaults(
        acr_result,
      ),
    )
  end

  def acr_result
    return nil if acr_values.blank?

    @acr_result = Vot::Parser.new(acr_values).parse_acr
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
    acr_result.component_values.filter { |cv| cv.name.include?('aal') }
  end

  def acr_ial_component_values
    acr_result.component_values.filter { |cv| cv.name.include?('ial') || cv.name.include?('loa') }
  end
end
