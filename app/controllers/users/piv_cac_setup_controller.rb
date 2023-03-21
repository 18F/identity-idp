module Users
  class PivCacSetupController < ApplicationController
    include PhoneConfirmation
    include ReauthenticationRequiredConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_recently_authenticated, if: -> do
      !IdentityConfig.store.reauthentication_for_second_factor_management_enabled
    end
    before_action :confirm_recently_authenticated_2fa, if: -> do
      IdentityConfig.store.reauthentication_for_second_factor_management_enabled
    end

    def delete; end

    def confirm_delete; end
  end
end
