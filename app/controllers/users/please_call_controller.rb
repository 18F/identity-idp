# frozen_string_literal: true

module Users
  class PleaseCallController < ApplicationController
    before_action :confirm_signed_in?

    def show
      analytics.user_suspended_please_call_visited
    end

    def confirm_signed_in?
      return if user_signed_in?
      redirect_to root_url
    end
  end
end
