module Users
  class Aal3Controller < ApplicationController
    def show
      render :'two_factor_authentication/options/no_option'
    end
  end
end
