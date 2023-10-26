module Idv
  class HowToVerifyForm
    include ActiveModel::Model

    def submit(params)
      FormResponse.new(success: valid?, errors: errors)
    end
  end
end
