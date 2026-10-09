# frozen_string_literal: true

# The confirmation page for approving applications in advance from the account page: the service
# provider card and the selected applications, grouped by agency, in the same registry content
# the consent screen shows, so the person decides on the same information either way.
class DelegationApprovalPresenter
  attr_reader :service_provider, :applications

  # @param service_provider [ServiceProvider]
  # @param applications [Array<ServiceProvider>] the selected applications, already validated to
  #   be active, to accept this service provider, and to lack a current remembered approval
  def initialize(service_provider:, applications:)
    @service_provider = service_provider
    @applications = applications
  end

  def card
    @card ||= DelegationServiceProviderCard.new(service_provider)
  end

  def sp_name
    card.name
  end

  # @return [Array<[Agency, Array<ServiceProvider>]>]
  def agency_groups
    @agency_groups ||= begin
      ActiveRecord::Associations::Preloader.new(
        records: applications, associations: [:agency, :token_exchange_resource_servers],
      ).call
      DelegationApplications.grouped_by_agency(applications)
    end
  end

  # How long an approval made here lasts, in months.
  def remember_months
    (TokenExchangeGrant::MAX_REMEMBER / 1.month).round
  end
end
