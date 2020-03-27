module Px
  class BasicInfoForm
    include ActiveModel::Model

    attr_reader :first_name, :last_name, :dob, :ssn, :address1, :address2, :city,
                :state, :zipcode

    def submit(_params)
      FormResponse.new(success: true, errors: {})
    end
  end
end
