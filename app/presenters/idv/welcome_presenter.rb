# frozen_string_literal: true

module Idv
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

    def initialize(decorated_sp_session:, passport_allowed:)
      @decorated_sp_session = decorated_sp_session
      @passport_allowed = passport_allowed
      @url_options = {}
    end

    def sp_name
      decorated_sp_session.sp_name || APP_NAME
    end

    def title
      t('doc_auth.headings.welcome', sp_name: sp_name)
    end

    def explanation_text(help_link)
      if first_time_idv?
        t(
          'doc_auth.info.getting_started_html',
          sp_name:,
          link_html: help_link,
        )
      else
        t(
          'doc_auth.info.stepping_up_html',
          link_html: help_link,
        )
      end
    end

    def bullet_points
      [
        bullet_point(
          id_type_copy,
          t('doc_auth.instructions.text1'),
        ),

        bullet_point(
          t('doc_auth.instructions.bullet2'),
          t('doc_auth.instructions.text2'),
        ),

        bullet_point(
          t('doc_auth.instructions.bullet3'),
          t('doc_auth.instructions.text3'),
        ),

        bullet_point(
          t('doc_auth.instructions.bullet4', app_name: APP_NAME),
          t('doc_auth.instructions.text4'),
        ),
      ]
    end

    private

    attr_reader :decorated_sp_session, :passport_allowed

    def current_user
      decorated_sp_session&.current_user
    end

    def id_type_copy
      return t('doc_auth.instructions.bullet1b') if passport_allowed

      t('doc_auth.instructions.bullet1a')
    end

    def bullet_point(bullet, text)
      BulletPoint.new(bullet: bullet, text: text)
    end

    def first_time_idv?
      !decorated_sp_session&.current_user&.active_profile?
    end
  end
end
