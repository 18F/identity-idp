# frozen_string_literal: true

module Users
  class PasswordCompromisedController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      session.delete(:redirect_to_password_compromised)
      @after_sign_in_path = after_sign_in_path_for(current_user)
      analytics.user_password_compromised_visited
    end
  end
  end
