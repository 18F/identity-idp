module Users
  class Aal3RejectionController < ApplicationController

    def show
      render :'two_factor_authentication/options/no_option'
    end
  end
end
