# frozen_string_literal: true

class Idv::PhonePresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TranslationHelper

  attr_reader :url_options, :gpo_letter_available

  def initialize(gpo_letter_available:, skip_phone_verification:, url_options:)
    @gpo_letter_available = gpo_letter_available
    @skip_phone_verification = skip_phone_verification
    @url_options = url_options
  end

  def title
    skip_phone_verification ?
      t('titles.idv.phone_skip_verification') :
      t('titles.idv.phone')
  end

  def heading
    skip_phone_verification ?
      t('titles.idv.phone_skip_verification') :
      t('titles.idv.phone')
  end

  def description
    skip_phone_verification ?
      t('idv.messages.phone.description_skip_verification') :
      t('idv.messages.phone.description')
  end

  def troubleshooting_options
    gpo_letter_available ? [gpo_troubleshooting_options] : []
  end

  def phone_failure_alert_body
    gpo_letter_available ? gpo_alert_body : try_again_alert_body
  end

  private

  attr_reader :skip_phone_verification

  def gpo_troubleshooting_options
    { url: idv_request_letter_path, text: t('idv.troubleshooting.options.verify_by_mail') }
  end

  def gpo_alert_body
    t(
      'idv.messages.phone.failed_number.gpo_alert_html',
      link_html: link_to(
        t('idv.messages.phone.failed_number.gpo_verify_link'),
        idv_request_letter_path,
      ),
    )
  end

  def try_again_alert_body
    t('idv.messages.phone.failed_number.try_again_html')
  end
end
