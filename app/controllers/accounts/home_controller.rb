# frozen_string_literal: true

module Accounts
  class HomeController < ApplicationController
    include RememberDeviceConcern
    before_action :confirm_two_factor_authenticated
    before_action :confirm_user_is_not_suspended

    layout 'account_side_nav'

    def show
      analytics.connected_services_page_visited
      cacher = Pii::Cacher.new(current_user, user_session)
      @presenter = AccountHomePresenter.new(
        user: current_user,
        decrypted_pii: cacher.fetch(current_user.active_or_pending_profile&.id),
        now: Time.zone.now,
        category: params[:category],
      )
    end

    private

    def confirm_user_is_not_suspended
      redirect_to user_please_call_url if current_user.suspended?
    end
  end
end
