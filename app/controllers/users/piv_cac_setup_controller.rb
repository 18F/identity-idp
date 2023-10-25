# frozen_string_literal: true

module Users
  class PivCacSetupController < ApplicationController
    include PhoneConfirmation
    include ReauthenticationRequiredConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_recently_authenticated_2fa

    def delete; end

    def confirm_delete; end
  end
end
