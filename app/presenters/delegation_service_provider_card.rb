# frozen_string_literal: true

# What a screen says about a service provider approved for delegated access, in the service
# provider's own registry content: who runs it, what it does, whether it uses AI, how it handles
# the person's information, and where to learn more. Shared by the consent screen and the
# account page so both describe the service provider identically.
class DelegationServiceProviderCard
  attr_reader :service_provider

  def initialize(service_provider)
    @service_provider = service_provider
  end

  def name
    service_provider.friendly_name || service_provider.agency&.name
  end

  def logo_url
    service_provider.logo.present? ? service_provider.logo_url : nil
  end

  def operator_name
    service_provider.delegation_operator_legal_name.presence || name
  end

  def service_description
    service_provider.delegation_service_description_for
  end

  def data_handling_statement
    service_provider.delegation_data_handling_statement_for
  end

  def uses_ai?
    service_provider.delegation_uses_ai?
  end

  def ai_description
    service_provider.delegation_ai_description_for
  end

  def learn_more_url
    service_provider.delegation_privacy_policy_url.presence
  end
end
