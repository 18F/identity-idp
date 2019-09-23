module Db
  module ProofingComponent
    class DeleteAll
      def self.call(user_id)
        ::ProofingComponent.where(user_id: user_id).delete_all
      end
    end
  end
end
