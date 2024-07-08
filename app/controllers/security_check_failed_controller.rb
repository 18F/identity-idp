# frozen_string_literal: true

class SecurityCheckFailedController < ApplicationController
  def show
    @presenter = SecurityCheckFailedPresenter.new
    analytics.security_check_failed_visited
  end
end
