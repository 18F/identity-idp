# frozen_string_literal: true

# The applications a broker service provider may reach by token exchange: every
# active service provider that has opted in to that broker by allow-listing it
# in its own configuration (`allowed_token_exchange_brokers`, set in the partner
# management portal). This is the authoritative reach of a broker -- a target
# decides for itself which brokers it accepts, and a broker simply never
# requests a target it does not support -- so no broker-asserted allowlist is
# needed or consulted.
module TokenExchangeReachableTargets
  module_function

  # @param broker_issuer [String]
  # @return [Array<ServiceProvider>] sorted by display name
  def for_broker(broker_issuer)
    return [] if broker_issuer.blank?

    ServiceProvider.active
      .where('? = ANY(allowed_token_exchange_brokers)', broker_issuer)
      .sort_by { |sp| sp.display_name.to_s.downcase }
  end
end
