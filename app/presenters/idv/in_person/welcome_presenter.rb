# frozen_string_literal: true

module Idv
  module InPerson
    class WelcomePresenter
      BulletPoint = Struct.new(
        :bullet,
        :text,
        keyword_init: true,
      )
      include ActionView::Helpers::TranslationHelper
      include Rails.application.routes.url_helpers
      include LinkHelper
      include ActionView::Helpers::UrlHelper

      attr_accessor :url_options

      def initialize(decorated_sp_session:)
        @decorated_sp_session = decorated_sp_session
        @url_options = {}
      end

      def sp_name
        decorated_sp_session.sp_name || APP_NAME
      end

      def bullet_points
        [
          bullet_point(
            t('in_person_proofing.body.prepare.verify_step_post_office'),
          ),

          bullet_point(
            t('in_person_proofing.body.prepare.verify_step_enter_pii'),
          ),

          bullet_point(
            t('in_person_proofing.body.prepare.verify_step_enter_phone'),
          ),
        ]
      end

      def privacy_policy_url
        MarketingSite.security_and_privacy_how_it_works_url
      end

      def phone_number_url
        MarketingSite.help_center_article_url(
          category: 'verify-your-identity',
          article: 'phone-number',
        )
      end

      def verify_your_identity_in_person_url
        MarketingSite.help_center_article_url(
          category: 'verify-your-identity',
          article: 'verify-your-identity-in-person',
        )
      end

      def app_name
        APP_NAME
      end

      private

      attr_reader :decorated_sp_session

      def current_user
        decorated_sp_session&.current_user
      end

      def bullet_point(text)
        BulletPoint.new(bullet: nil, text:)
      end
    end
  end
end
