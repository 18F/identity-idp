module Px
  class BankAccountInfoForm
    include ActiveModel::Model

    attr_reader :routing_number, :account_number

    def submit(_params)
      FormResponse.new(success: true, errors: {})
    end
  end
end
