# This class overrides the default `i18n_message` defined by Devise
# in order to allow customizing the `devise.failure.invalid` and
# 'devise.failure.not_found_in_database' error messages with a link
# that preserves the locale and request_id.
class CustomDeviseFailureApp < Devise::FailureApp
  def i18n_message(default = nil)
    message = warden_message || default || :unauthenticated

    message.is_a?(Symbol) ? build_message(message) : message.to_s
  end

  private

  def build_message(message)
    options = build_options(message)

    if %i[invalid not_found_in_database].include?(message)
      customized_message(message)
    else
      I18n.t(:"#{scope}.#{message}", options)
    end
  end

  def build_options(message)
    options = {}
    options[:resource_name] = scope
    options[:scope] = 'devise.failure'
    options[:default] = [message]
    i18n_options(options)
  end

  def customized_message(message)
    prefix = "devise.failure.#{message}"
    link = helper.link_to(
      I18n.t("#{prefix}_link_text"),
      new_user_password_url(locale: locale_url_param, request_id: sp_session[:request_id]),
    )
    I18n.t("#{prefix}_html", link: link)
  end

  def helper
    ActionController::Base.helpers
  end

  def locale_url_param
    active_locale = I18n.locale
    active_locale == I18n.default_locale ? nil : active_locale
  end

  def sp_session
    session.fetch(:sp, {})
  end
end
