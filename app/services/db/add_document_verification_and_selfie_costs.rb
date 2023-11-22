module Db
  class AddDocumentVerificationAndSelfieCosts
    def initialize(user_id:, service_provider:)
      @service_provider = service_provider
      @user_id = user_id
    end

    def call(client_response)
      add_cost(:acuant_front_image)
      add_cost(:acuant_back_image)
      add_cost(:acuant_result) if client_response.to_h[:billed]
    end

    private

    attr_reader :service_provider, :user_id

    def add_cost(token)
      Db::SpCost::AddSpCost.call(service_provider, 2, token)
    end
  end
end
