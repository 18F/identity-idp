# frozen_string_literal: true

module Test
  class PushNotificationController < ApplicationController
    layout 'no_card'

    before_action :render_not_found_in_production

    def index
      @events = PushNotification::LocalEventQueue.events
    end

    def destroy
      PushNotification::LocalEventQueue.clear!
      redirect_to test_push_notification_url
    end

    private

    def render_not_found_in_production
      return unless Rails.env.production?
      render_not_found
    end
  end
end
