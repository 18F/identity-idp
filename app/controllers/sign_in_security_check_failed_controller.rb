# frozen_string_literal: true

class SignInSecurityCheckFailedController < ApplicationController
  def show
    analytics.security_check_failed_visited
  end
end
