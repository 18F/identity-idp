module Idv
  class CancellationsPresenter
    include Rails.application.routes.url_helpers
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper

    attr_reader :sp_name, :url_options

    def initialize(sp_name:, url_options:)
      @sp_name = sp_name
      @url_options = url_options
    end

    def exit_heading
      if sp?
        t('idv.cancel.headings.exit.with_sp', app_name: APP_NAME, sp_name: sp_name)
      else
        t('idv.cancel.headings.exit.without_sp')
      end
    end

    def exit_description
      if sp?
        t(
          'idv.cancel.description.exit.with_sp_html',
          app_name: APP_NAME,
          sp_name: sp_name,
          account_page_link: link_to(t('idv.cancel.description.account_page'), account_path),
        )
      else
        t(
          'idv.cancel.description.exit.without_sp',
          app_name: APP_NAME,
          account_page_text: t('idv.cancel.description.account_page'),
        )
      end
    end

    def exit_action_text
      if sp?
        t('idv.cancel.actions.exit', app_name: APP_NAME)
      else
        t('idv.cancel.actions.account_page')
      end
    end

    private

    def sp?
      sp_name.present?
    end
  end
end
