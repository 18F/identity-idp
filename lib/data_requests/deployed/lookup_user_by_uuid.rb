module DataRequests
  module Deployed
    class LookupUserByUuid
      attr_reader :uuid

      def initialize(uuid)
        @uuid = uuid
      end

      def call
        User.find_by(uuid:) ||
          ServiceProviderIdentity.find_by(uuid:)&.user
      end
    end
  end
end
