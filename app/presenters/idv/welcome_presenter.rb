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
      t(
        'doc_auth.info.getting_started_html',
        sp_name: sp_name,
        link_html: help_link,
      )
    end

    private

    attr_accessor :sp_session
  end
end
