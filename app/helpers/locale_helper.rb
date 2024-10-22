# frozen_string_literal: true

module LocaleHelper
  def locale_url_param
    active_locale = I18n.locale
    active_locale == I18n.default_locale ? nil : active_locale
  end

  def with_user_locale(user, &block)
    locale = user.email_language

    if I18n.locale_available?(locale)
      if defined?(url_options)
        I18n.with_locale(locale) do
          url_options_locale = url_options[:locale]
          url_options[:locale] = locale
          block.call
        ensure
          url_options[:locale] = url_options_locale
        end
      else
        I18n.with_locale(locale, &block)
      end
    else
      Rails.logger.warn("user_id=#{user.uuid} has bad email_language=#{locale}") if locale.present?

      yield
    end
  end
end
