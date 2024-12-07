# frozen_string_literal: true

module Idv
  module ByMail
    class SpFollowUpPresenter
      include ActionView::Helpers::TranslationHelper

      attr_reader :current_user

      def initialize(current_user:)
        @current_user = current_user
      end

      def heading
        t(
          'idv.by_mail.sp_follow_up.heading',
          service_provider: initiating_service_provider_name,
        )
      end

      def body
        t(
          'idv.by_mail.sp_follow_up.body',
          service_provider: initiating_service_provider_name,
          app_name: APP_NAME,
        )
      end

      private

      def initiating_service_provider_name
        initiating_service_provider.friendly_name
      end

      def initiating_service_provider
        @initiating_service_provider ||= current_user.active_profile.initiating_service_provider
      end
    end
  end
end
