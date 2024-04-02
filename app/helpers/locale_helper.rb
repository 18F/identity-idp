# frozen_string_literal: true

module LocaleHelper
  def locale_url_param
    active_locale = I18n.locale
    active_locale == I18n.default_locale ? nil : active_locale
  end

  def with_user_locale(user, &block)
    locale = user.email_language

    if I18n.locale_available?(locale)
      I18n.with_locale(locale, &block)
    else
      Rails.logger.warn("user_id=#{user.uuid} has bad email_language=#{locale}") if locale.present?

      yield
    end
  end
end
