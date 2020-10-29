module LocaleHelper
  def locale_url_param
    active_locale = I18n.locale
    active_locale == I18n.default_locale ? nil : active_locale
  end

  def with_user_locale(user, &block)
    if user.email_language.present?
      I18n.with_locale(user.email_language, &block)
    else
      yield
    end
  end
end
