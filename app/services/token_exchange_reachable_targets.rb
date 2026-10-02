# frozen_string_literal: true

# The applications a broker service provider may currently reach by token
# exchange, resolved to active service providers that have opted in to that
# broker. Sourced from the broker's signed manifest, so this is exactly the set a
# grant can ever be honored for; a target not yet onboarded, inactive, or not
# opted in to this broker is omitted.
module TokenExchangeReachableTargets
  module_function

  # @param broker_issuer [String]
  # @return [Array<ServiceProvider>] sorted by display name
  def for_broker(broker_issuer)
    issuers = TokenExchangeManifest.allowed_targets(broker_issuer)
    return [] if issuers.blank?

    ServiceProvider.active.where(issuer: issuers)
      .select { |sp| sp.allows_token_exchange_broker?(broker_issuer) }
      .sort_by { |sp| sp.display_name.to_s.downcase }
  end
end
