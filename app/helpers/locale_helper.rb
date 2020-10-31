module LocaleHelper
  def locale_url_param
    active_locale = I18n.locale
    active_locale == I18n.default_locale ? nil : active_locale
  end

  def with_user_locale(user, &block)
    email_language = user.email_language

    if email_language.present?
      return I18n.with_locale(email_language, &block) if I18n.locale_available?(email_language)

      Rails.logger.warn("user_id=#{user.uuid} has bad email_language=#{email_language}")
    end

    yield
  end
end
