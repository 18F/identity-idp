class AgencyIdentityLinker
  def initialize(sp_identity)
    @sp_identity = sp_identity
    @agency_id = nil
  end

  def link_identity
    ai = agency_identity_from_sp_identity
    return ai if ai
    create_agency_identity_for_sp || AgencyIdentity.new(user_id: @sp_identity.user_id,
                                                        uuid: @sp_identity.uuid)
  end

  def self.sp_identity_from_uuid_and_sp(uuid, service_provider)
    agency_identity = AgencyIdentity.where(uuid: uuid).first
    criteria = if agency_identity
                 { user_id: agency_identity.user_id, service_provider: service_provider }
               else
                 { uuid: uuid, service_provider: service_provider }
               end
    Identity.where(criteria).first
  end

  def self.sp_identity_from_uuid(uuid)
    agency_identity = AgencyIdentity.where(uuid: uuid).first
    return Identity.where(uuid: uuid).first if agency_identity.nil?
    service_provider = ServiceProvider.where(agency_id: agency_identity.agency_id).first
    return unless service_provider
    sp_identity_from_uuid_and_sp(agency_identity.uuid, service_provider.issuer)
  end

  private

  def create_agency_identity_for_sp
    return unless @agency_id
    AgencyIdentity.create(agency_id: @agency_id,
                          user_id: @sp_identity.user_id,
                          uuid: @sp_identity.uuid)
  end

  def agency_identity_from_sp_identity
    agency_identity = AgencyIdentity.where(uuid: @sp_identity.uuid).first
    return agency_identity unless agency_identity.nil?
    sp = ServiceProvider.where(issuer: @sp_identity.service_provider).first
    @agency_id = sp&.agency_id
    return unless @agency_id
    AgencyIdentity.where(agency_id: @agency_id, user_id: @sp_identity.user_id).first
  end
end
