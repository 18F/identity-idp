module Idv
  class WelcomePresenter
    include ActionView::Helpers::TranslationHelper

    def initialize(sp_session)
      @sp_session = sp_session
    end

    def sp_name
      sp_session.sp_name || APP_NAME
    end

    def title
      t('doc_auth.headings.welcome', sp_name: sp_name)
    end

    private

    attr_accessor :sp_session
  end
end
