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
        current_locale = I18n.locale
        I18n.with_locale(locale) do
          url_options[:locale] = locale
          block.call
          url_options[:locale] = current_locale
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
