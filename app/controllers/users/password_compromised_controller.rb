# frozen_string_literal: true

module Users
    class PasswordCompromisedController < ApplicationController
      before_action :confirm_two_factor_authenticated
  
      def show
        analytics.user_password_compromised_visited
      end
    end
  end
  