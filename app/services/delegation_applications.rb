# frozen_string_literal: true

# Which applications a service provider may be delegated access to, as the registry defines it.
#
# An application is an agency-owned service provider record with `delegation_application: true`.
# Each application decides which service providers it accepts
# (`allowed_delegation_service_providers`); an empty list means any service provider Login.gov
# has approved for delegation. That registry, not the user's connection history, is the reach of
# a service provider.
module DelegationApplications
  module_function

  # Every active application that accepts the given service provider.
  # @param service_provider_issuer [String]
  # @return [Array<ServiceProvider>] sorted by display name
  def accepting(service_provider_issuer)
    return [] if service_provider_issuer.blank?

    sort(
      ServiceProvider.active
        .where(delegation_application: true)
        .where(
          # Either the application lists no service providers (accepts any approved one) or it
          # lists this one.
          'cardinality(allowed_delegation_service_providers) = 0 ' \
          'OR ? = ANY(allowed_delegation_service_providers)',
          service_provider_issuer,
        ),
    )
  end

  # The subset of #accepting that the user has already connected to (a live identity).
  # @return [Array<ServiceProvider>] sorted by display name
  def connected_for(user:, service_provider_issuer:)
    return [] if user.blank? || service_provider_issuer.blank?

    connected_issuers = user.connected_apps.pluck(:service_provider) - [service_provider_issuer]
    return [] if connected_issuers.empty?

    accepting(service_provider_issuer).select { |app| connected_issuers.include?(app.issuer) }
  end

  # Groups applications under their agency for display.
  # @return [Array<[Agency, Array<ServiceProvider>]>] agencies sorted by name, each with its
  #   applications sorted by display name
  def grouped_by_agency(applications)
    applications.group_by(&:agency)
      .sort_by { |agency, _| agency&.name.to_s.downcase }
      .map { |agency, apps| [agency, sort(apps)] }
  end

  def sort(applications)
    applications.sort_by { |app| app.display_name.to_s.downcase }
  end
end
