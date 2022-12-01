module DataRequests
  class LookupUserByUuid
    attr_reader :uuid

    def initialize(uuid)
      @uuid = uuid
    end

    def call
      # mattw: This seems like a confusing use case. Used only in data_requests.rake FWIW.
      User.find_by(uuid: uuid) ||
        ServiceProviderIdentity.consented.find_by(uuid: uuid)&.user
    end
  end
end
