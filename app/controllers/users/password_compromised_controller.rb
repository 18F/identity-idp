# frozen_string_literal: true

module Users
  class PasswordCompromisedController < ApplicationController
    before_action :confirm_two_factor_authenticated
    before_action :verify_feature_toggle_on?

    def show
      session.delete(:redirect_to_password_compromised)
      @after_sign_in_path = after_sign_in_path_for(current_user)
      analytics.user_password_compromised_visited
    end

    def verify_feature_toggle_on?
      redirect_to after_sign_in_path_for(current_user) unless FeatureManagement.check_password_enabled?
    end
  end
end
