module Idv
  class HowToVerifyForm
    include ActiveModel::Model

    def submit(_params)
      FormResponse.new(success: valid?, errors: errors)
    end
  end
end
