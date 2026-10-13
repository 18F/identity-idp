# frozen_string_literal: true

# Delegated-access state for one connected service provider on the account page: the
# applications it may act at, grouped by agency, each with the user's current approval.
class DelegationServiceProviderPresenter
  attr_reader :user, :service_provider

  def initialize(user:, service_provider:)
    @user = user
    @service_provider = service_provider
  end

  # @return [Array<[Agency, Array<ServiceProvider>]>]
  def applications_by_agency
    @applications_by_agency ||= DelegationApplications.grouped_by_agency(applications)
  end

  # The applications shown for this service provider: those the user has connected to that
  # accept it.
  # @return [Array<ServiceProvider>]
  def applications
    @applications ||= DelegationApplications.connected_for(
      user:, service_provider_issuer: service_provider.issuer,
    )
  end

  def any_applications?
    applications.any?
  end

  # @return [TokenExchangeGrant, nil] the live approval for an application, if any
  def grant_for(application)
    live_grants_by_application_id[application.id]
  end

  def approved?(application)
    grant_for(application).present?
  end

  private

  def live_grants_by_application_id
    @live_grants_by_application_id ||= TokenExchangeGrant.live
      .where(user:, service_provider_issuer: service_provider.issuer)
      .index_by(&:application_service_provider_id)
  end
end
