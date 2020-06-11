module Users
  class Aal3RejectionController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      render :'two_factor_authentication/options/no_option'
    end
  end
end
