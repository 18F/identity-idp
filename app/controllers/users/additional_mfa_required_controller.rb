module Users
  class AdditionalMfaRequiredController < ApplicationController
    extend ActiveSupport::Concern

    def show
      @content = AdditionalMfaRequiredPresenter.new
    end

    def skip
      user_session[:skip_kantara_req] = true
      redirect_to after_sign_in_path_for(current_user)
    end
  end
end
  