class AgencyIdentityLinker
  def initialize(sp_identity)
    @sp_identity = sp_identity
    @agency_id = nil
  end

  def link_identity
    find_or_create_agency_identity ||
      AgencyIdentity.new(user_id: @sp_identity.user_id, uuid: @sp_identity.uuid)
  end

  def self.sp_identity_from_uuid_and_sp(uuid, service_provider)
    ai = AgencyIdentity.where(uuid: uuid).first
    criteria = if ai
                 { user_id: ai.user_id, service_provider: service_provider }
               else
                 { uuid: uuid, service_provider: service_provider }
               end
    Identity.where(criteria).first
  end

  def self.sp_identity_from_uuid(uuid)
    ai = AgencyIdentity.where(uuid: uuid).first
    return Identity.where(uuid: uuid).first if ai.nil?
    service_provider = ServiceProvider.where(agency_id: ai.agency_id).first
    return unless service_provider
    sp_identity_from_uuid_and_sp(ai.uuid, service_provider.issuer)
  end

  private

  def find_or_create_agency_identity
    agency_identity || create_agency_identity_for_sp
  end

  def create_agency_identity_for_sp
    return unless agency_id
    AgencyIdentity.create(agency_id: agency_id,
                          user_id: @sp_identity.user_id,
                          uuid: @sp_identity.uuid)
  end

  def agency_identity
    ai = AgencyIdentity.where(uuid: @sp_identity.uuid).first
    return ai if ai
    sp = ServiceProvider.where(issuer: @sp_identity.service_provider).first
    return unless agency_id(sp)
    AgencyIdentity.where(agency_id: agency_id, user_id: @sp_identity.user_id).first
  end

  def agency_id(service_provider = nil)
    @agency_id ||= service_provider&.agency_id
  end
end
