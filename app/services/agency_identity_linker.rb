# frozen_string_literal: true

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
  #   service provider if one exists, otherwise creates one.
  def self.for(user:, service_provider:, skip_create:)
    agency = service_provider.agency

    ai = AgencyIdentity.find_by(user: user, agency: agency)
    return ai if ai.present? || skip_create
    # This should never be the case and we should fail loudly if it is
    raise "nil agency_id for #{service_provider.issuer}" unless service_provider.agency_id

    spi = ServiceProviderIdentity.find_by(
      user: user, service_provider: service_provider.issuer,
    )

    uuid = spi&.uuid || SecureRandom.uuid
    AgencyIdentity.create(
      agency_id: service_provider.agency_id,
      user_id: user.id,
      uuid: uuid,
    )
  end

  def self.sp_identity_from_uuid_and_sp(uuid, service_provider)
    ai = AgencyIdentity.find_by(uuid: uuid)
    criteria = if ai
                 { user_id: ai.user_id, service_provider: service_provider }
               else
                 { uuid: uuid, service_provider: service_provider }
               end
    ServiceProviderIdentity.find_by(criteria)
  end

  private

  def find_or_create_agency_identity
    agency_identity || create_agency_identity_for_sp
  end

  def create_agency_identity_for_sp
    return unless agency_id
    AgencyIdentity.create_or_find_by(
      agency_id: agency_id,
      user_id: @sp_identity.user_id,
      uuid: @sp_identity.uuid,
    )
  end

  def agency_identity
    ai = AgencyIdentity.find_by(uuid: @sp_identity.uuid)
    return ai if ai
    sp = ServiceProvider.find_by(issuer: @sp_identity.service_provider)
    return unless agency_id(sp)
    AgencyIdentity.find_by(agency_id: agency_id, user_id: @sp_identity.user_id)
  end

  def agency_id(service_provider = nil)
    @agency_id ||= service_provider&.agency_id
  end
end
