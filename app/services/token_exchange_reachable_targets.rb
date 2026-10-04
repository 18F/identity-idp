# frozen_string_literal: true

# The applications a broker service provider may reach by token exchange.
#
# A target decides for itself which brokers it accepts, by allow-listing them in
# its own configuration (`allowed_token_exchange_brokers`, set in the partner
# management portal). That opt-in is the authoritative reach of a broker; there
# is no broker-asserted allowlist, because a broker simply never requests a
# target it does not support.
module TokenExchangeReachableTargets
  module_function

  # Every active service provider that has opted in to the broker.
  # @return [Array<ServiceProvider>] sorted by display name
  def for_broker(broker_issuer)
    return [] if broker_issuer.blank?

    sort(ServiceProvider.active.where('? = ANY(allowed_token_exchange_brokers)', broker_issuer))
  end

  # The subset of the broker's reach the USER has already linked to their
  # account (a live, non-deleted identity). This is what "allow all agencies
  # linked to your account" covers and what the per-application chooser lists.
  # @return [Array<ServiceProvider>] sorted by display name
  def linked_for(user:, broker_issuer:)
    return [] if user.blank? || broker_issuer.blank?

    linked_issuers = user.connected_apps.pluck(:service_provider) - [broker_issuer]
    return [] if linked_issuers.empty?

    sort(
      ServiceProvider.active
        .where(issuer: linked_issuers)
        .where('? = ANY(allowed_token_exchange_brokers)', broker_issuer),
    )
  end

  # Groups service providers under their agency for display.
  # @return [Array<[Agency, Array<ServiceProvider>]>] agencies sorted by name,
  #   each with its providers sorted by display name
  def grouped_by_agency(service_providers)
    service_providers.group_by(&:agency)
      .sort_by { |agency, _| agency&.name.to_s.downcase }
      .map { |agency, sps| [agency, sort(sps)] }
  end

  def sort(service_providers)
    service_providers.sort_by { |sp| sp.display_name.to_s.downcase }
  end
end
