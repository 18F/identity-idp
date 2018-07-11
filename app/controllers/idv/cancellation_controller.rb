module Idv
  class CancellationController < ApplicationController
    include IdvSession

    #before_action :confirm_two_factor_authenticated
    #before_action :confirm_idv_needed

    def show
      @presenter = CancellationPresenter.new
      @go_back_path = case current_step
                      when :jurisdiction
                        idv_jurisdiction_path
                      else
                        idv_session_path
                      end
    end

    def destroy
      idv_session = user_session[:idv]
      idv_session&.clear
      handle_idv_redirect
    end

    private

    def current_step
      params[:step].to_sym
    end

    def handle_idv_redirect
      redirect_to account_url and return if current_user.personal_key.present?
      user_session[:personal_key] = create_new_code
      redirect_to manage_personal_key_url
    end
  end
end
