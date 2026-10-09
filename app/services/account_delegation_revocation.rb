# frozen_string_literal: true

# Ends, from the account page, the person's standing approvals for delegated access, at one of
# three scopes: one application of one service provider, everything for one service provider, or
# everything for every service provider. Rows are revoked, never deleted, so the record of what
# was approved and when it ended is kept.
class AccountDelegationRevocation
  REASON = 'user_revoked'

  # @param user [User]
  # @param service_provider [ServiceProvider, nil] nil to revoke across every service provider
  # @param application [ServiceProvider, nil] nil to revoke every application of the service
  #   provider; requires +service_provider+ when given
  def initialize(user:, service_provider: nil, application: nil)
    @user = user
    @service_provider = service_provider
    @application = application
  end

  # The live approvals this revocation would end, in a stable order for display.
  # @return [Array<TokenExchangeGrant>]
  def grants
    @grants ||= scope.includes(:application).order(:service_provider_issuer, :id).to_a
  end

  def scope_name
    if application
      'application'
    elsif service_provider
      'service_provider'
    else
      'all'
    end
  end

  # Revokes every approval in scope with one reason, in one transaction.
  # @return [Array<TokenExchangeGrant>] the rows that were revoked
  def call
    now = Time.zone.now
    TokenExchangeGrant.transaction do
      grants.each { |grant| grant.revoke!(reason: REASON, now:) }
    end
    grants
  end

  private

  attr_reader :user, :service_provider, :application

  def scope
    relation = TokenExchangeGrant.live.where(user:)
    relation = relation.where(service_provider_issuer: service_provider.issuer) if service_provider
    relation = relation.where(application:) if application
    relation
  end
end
