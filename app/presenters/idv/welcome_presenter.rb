# frozen_string_literal: true

module Idv
  class WelcomePresenter
    include ActionView::Helpers::TranslationHelper
    include Rails.application.routes.url_helpers
    include LinkHelper
    include ActionView::Helpers::UrlHelper

    attr_accessor :url_options

    def initialize(decorated_sp_session)
      @decorated_sp_session = decorated_sp_session
      @url_options = {}
    end

    def sp_name
      decorated_sp_session.sp_name || APP_NAME
    end

    def title
      t('doc_auth.headings.welcome', sp_name: sp_name)
    end

    def selfie_required?
      decorated_sp_session.selfie_required?
    end

    def explanation_text(help_link)
      if step_up_selfie_required?
        t(
          'doc_auth.info.stepping_up_html',
          sp_name:,
          link_html: help_link,
        )
      else
        t(
          'doc_auth.info.getting_started_html',
          sp_name: sp_name,
          link_html: help_link,
        )
      end
    end

    def bullet_points
      [
        if selfie_required?
          bullet_point(
            t('doc_auth.instructions.bullet1_with_selfie'),
            t('doc_auth.instructions.text1_with_selfie'),
          )
        else
          bullet_point(
            t('doc_auth.instructions.bullet1'),
            t('doc_auth.instructions.text1'),
          )
        end,

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

    attr_accessor :decorated_sp_session

    def current_user
      decorated_sp_session&.current_user
    end

    def bullet_point(bullet, text)
      OpenStruct.new(bullet: bullet, text: text)
    end

    def step_up_selfie_required?
      !!(current_user&.identity_verified? || current_user&.pending_profile?) &&
        selfie_required?
    end
  end
end
