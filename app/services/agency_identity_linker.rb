class AgencyIdentityLinker
  def initialize(sp_identity)
    @sp_identity = sp_identity
    @agency_id = nil
  end

  def link_identity
    find_or_create_agency_identity ||
      AgencyIdentity.new(user_id: @sp_identity.user_id, uuid: @sp_identity.uuid)
  end

  # @return [AgencyIdentity, ServiceProviderIdentity] the AgencyIdentity for this user at this
  #   service provider or falls back to the ServiceProviderIdentity if one does not exist.
  def self.for(user:, service_provider:)
    agency = service_provider.agency

    ai = AgencyIdentity.where(user: user, agency: agency).take
    return ai if ai.present?

    # mattw: Punting on this one for the moment, because this is where we're going to make our change I think.
    spi = ServiceProviderIdentity.where(
      user: user, service_provider: service_provider.issuer,
    ).take

    return nil unless spi.present?
    new(spi).link_identity
  end

  def self.sp_identity_from_uuid_and_sp(uuid, service_provider)
    ai = AgencyIdentity.where(uuid: uuid).take
    criteria = if ai
                 { user_id: ai.user_id, service_provider: service_provider }
               else
                 { uuid: uuid, service_provider: service_provider }
               end
    # mattw: Same, but I think we should change htis one
    ServiceProviderIdentity.where(criteria).take
  end

  private

  def find_or_create_agency_identity
    agency_identity || create_agency_identity_for_sp
  end

  def create_agency_identity_for_sp
    return unless agency_id
    AgencyIdentity.create(
      agency_id: agency_id,
      user_id: @sp_identity.user_id,
      uuid: @sp_identity.uuid,
    )
  end

  def agency_identity
    ai = AgencyIdentity.where(uuid: @sp_identity.uuid).take
    return ai if ai
    sp = ServiceProvider.where(issuer: @sp_identity.service_provider).take
    return unless agency_id(sp)
    AgencyIdentity.where(agency_id: agency_id, user_id: @sp_identity.user_id).take
  end

  def agency_id(service_provider = nil)
    @agency_id ||= service_provider&.agency_id
  end
end
