# frozen_string_literal: true

module NDS
  # Net-new NDS page footer chrome (renders only in the nds layout). Emits the
  # page-footer / footer-destination-* / footer-language-* class contract.
  #
  # NOTE (flagged): the footer-content classes are not styled yet (only the
  # .auth-page__footer-wrapper slot), so this renders inert/unstyled for now.
  # The class contract is emitted now so it lights up once the styles land. The
  # language/destination selects and the help link render via the
  # bucket-conditional ButtonComponent (quaternary in nds).
  class PageFooterChromeComponent < BaseComponent
    GSA_URL = 'https://www.gsa.gov'

    attr_reader :gsa_url, :help_url

    def initialize(
      agency_name: nil,
      gsa_url: GSA_URL,
      help_url: nil,
      language_options: nil,
      destination_options: nil
    )
      @agency_name = agency_name
      @gsa_url = gsa_url
      @help_url = help_url
      @language_options = language_options
      @destination_options = destination_options
    end

    def language_options
      @language_options || locale_urls.map do |locale, url|
        {
          label: t("i18n.locale.#{locale}"),
          value: url,
          lang: locale,
          selected: locale == I18n.locale,
        }
      end
    end

    def destination_options
      @destination_options || [
        { label: t('links.contact'), value: helpers.contact_redirect_url },
        {
          label: t('notices.privacy.privacy_act_statement'),
          value: MarketingSite.privacy_act_statement_url,
        },
        {
          label: t('links.accessibility_statement'),
          value: MarketingSite.accessibility_statement_url,
        },
      ]
    end

    def privacy_link
      {
        label: t('links.privacy_policy'),
        value: MarketingSite.security_and_privacy_practices_url,
      }
    end

    def resolved_help_url
      help_url || helpers.help_center_redirect_url
    end

    def selected_language_label
      language_options.find { |option| option[:selected] }&.fetch(:label) || t('i18n.language')
    end

    def more_label
      t('links.more')
    end

    def agency_name
      @agency_name || t('shared.footer_lite.gsa')
    end

    private

    def locale_urls
      I18n.available_locales.index_with { |locale| "/#{locale}#{fullpath_without_locale}" }
    end

    def fullpath_without_locale
      @fullpath_without_locale ||= begin
        path = request.fullpath
        path = path.slice(params[:locale].size + 1..) if params[:locale].present?
        path
      end
    end
  end
end
