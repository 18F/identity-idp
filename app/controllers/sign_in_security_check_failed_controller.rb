# frozen_string_literal: true

class SignInSecurityCheckFailedController < ApplicationController
  def show
    analytics.sign_in_security_check_failed_visited
  end
end
