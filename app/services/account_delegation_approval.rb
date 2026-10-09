# frozen_string_literal: true

# Records, from the account page, the person's advance approval of applications a service
# provider may act at for them. The person chose the applications and confirmed them on a page
# that showed the same content the consent screen shows; every approval made here is remembered
# for the maximum period, because there is no sign-in for a shorter approval to belong to.
class AccountDelegationApproval
  # @param user [User]
  # @param service_provider [ServiceProvider] the service provider being approved
  # @param applications [Array<ServiceProvider>] the applications the person selected
  def initialize(user:, service_provider:, applications:)
    @user = user
    @service_provider = service_provider
    @applications = applications
  end

  # Writes one remembered approval per application in one transaction, superseding any earlier
  # live row for the same application (for example a single-sign-in approval or a stale one).
  # @return [Array<TokenExchangeGrant>] the new live rows, in the order given
  def call
    now = Time.zone.now
    TokenExchangeGrant.transaction do
      applications.map do |application|
        TokenExchangeGrant.approve!(
          user:, service_provider:, application:,
          source: 'account_page', remember: true, now:
        )
      end
    end
  end

  private

  attr_reader :user, :service_provider, :applications
end
