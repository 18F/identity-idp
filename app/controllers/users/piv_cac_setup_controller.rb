module Users
  class PivCacSetupController < ReauthnRequiredController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated

    def delete
    end

    def confirm_delete; end
  end
end
