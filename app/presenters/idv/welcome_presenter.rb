module Idv
  class WelcomePresenter
    include ActionView::Helpers::TranslationHelper
    include Rails.application.routes.url_helpers
    include LinkHelper
    include ActionView::Helpers::UrlHelper

    attr_accessor :url_options

    def initialize(sp_session)
      @sp_session = sp_session
      @url_options = {}
    end

    def sp_name
      sp_session.sp_name || APP_NAME
    end

    def title
      t('doc_auth.headings.welcome', sp_name: sp_name)
    end

    def selfie_required?
      sp_session.selfie_required?
    end

    def explanation_text(help_link)
      if selfie_required?
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

    def bullet_header(index)
      case index
      when 1
        if selfie_required?
          t('doc_auth.instructions.bullet1_with_selfie')
        else
          t('doc_auth.instructions.bullet1')
        end
      when 2
        t('doc_auth.instructions.bullet2')
      when 3
        t('doc_auth.instructions.bullet3')
      when 4
        t('doc_auth.instructions.bullet4')
      end
    end

    def bullet_text(index)
      case index
      when 1
        if selfie_required?
          t('doc_auth.instructions.text1_with_selfie')
        else
          t('doc_auth.instructions.text1')
        end
      when 2
        t('doc_auth.instructions.text2')
      when 3
        t('doc_auth.instructions.text3')
      when 4
        t('doc_auth.instructions.text4')
      end
    end

    private

    attr_accessor :sp_session
  end
end
