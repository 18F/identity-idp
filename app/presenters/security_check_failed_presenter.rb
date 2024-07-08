# frozen_string_literal: true

class SecurityCheckFailedPresenter
  def troubleshooting_options
    [
      BlockLinkComponent.new(
        url: MarketingSite.contact_url,
        new_tab: true,
      ).with_content(I18n.t('security_check_failed.contact', app_name: APP_NAME)),
    ]
  end
end
