# frozen_string_literal: true

# The Account > Delegated access page: one section per service provider approved for delegated
# access, whether or not the person has signed in to it, listing every registered application
# that accepts that service provider, grouped by agency, with the person's standing (remembered)
# approval for each. Approvals given for a single sign-in are not standing permissions and are
# not listed.
class DelegatedAccessPresenter
  # One application row: the registry record and the person's live remembered approval, if any.
  Row = Struct.new(:application, :grant, keyword_init: true) do
    def approved?
      grant.present?
    end
  end

  # One service provider section. `agency_groups` is [[Agency, [Row]]]; `approvable?` is false
  # for a service provider that is no longer approved or active: its section then only offers
  # revocation of what remains.
  Section = Struct.new(
    :service_provider, :card, :agency_groups, :approvable?, keyword_init: true
  ) do
    def rows
      agency_groups.flat_map { |_agency, rows| rows }
    end

    def approved_rows
      rows.select(&:approved?)
    end

    def approvable_rows
      return [] unless approvable?

      rows.reject(&:approved?)
    end
  end

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  # Sections in display-name order: every active service provider approved for delegation, plus
  # any other service provider the person still has a remembered approval for (so it can be
  # revoked even after the service provider lost approval or was deactivated).
  # @return [Array<Section>]
  def sections
    @sections ||= service_providers.map { |service_provider| build_section(service_provider) }
      .reject { |section| section.rows.empty? }
  end

  # Whether the page offers "End all delegated access": true while any standing approval exists.
  def any_approvals?
    remembered_grants.any?
  end

  private

  def service_providers
    approved = ServiceProvider.active.where(token_exchange_enabled_sp: true)
    with_grants = ServiceProvider.where(issuer: remembered_grants.map(&:service_provider_issuer))
    (approved.to_a + with_grants.to_a).uniq(&:id)
      .sort_by { |sp| (sp.friendly_name || sp.agency&.name).to_s.downcase }
  end

  def build_section(service_provider)
    grants = remembered_grants.select { |g| g.service_provider_issuer == service_provider.issuer }
    grants_by_application_id = grants.index_by(&:application_service_provider_id)
    applications = (
      DelegationApplications.accepting(service_provider.issuer) + grants.map(&:application)
    ).uniq(&:id)
    ActiveRecord::Associations::Preloader.new(
      records: applications, associations: [:agency, :token_exchange_resource_servers],
    ).call
    groups = DelegationApplications.grouped_by_agency(applications).map do |agency, apps|
      [agency, apps.map do |app|
        Row.new(application: app, grant: grants_by_application_id[app.id])
      end]
    end
    Section.new(
      service_provider:,
      card: DelegationServiceProviderCard.new(service_provider),
      agency_groups: groups,
      approvable?: service_provider.delegation_service_provider?,
    )
  end

  # The person's live, remembered approvals across every service provider, each bound to its
  # application record.
  def remembered_grants
    @remembered_grants ||= TokenExchangeGrant.remembered.where(user:).includes(:application).to_a
  end
end
