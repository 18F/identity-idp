module DataRequests
  class LookupUserByUuid
    attr_reader :uuid

    def initialize(uuid)
      @uuid = uuid
    end

    def call
      User.find_by(uuid: uuid) ||
        Identity.find_by(uuid: uuid)&.user
    end
  end
end
