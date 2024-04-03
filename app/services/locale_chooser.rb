# frozen_string_literal: true

class LocaleChooser
  include HttpAcceptLanguage::EasyAccess

  def initialize(locale_param, request)
    @locale_param = locale_param
    @request = request
  end

  def locale
    return locale_param if locale_valid?
    http_accept_language.compatible_language_from(I18n.available_locales) || I18n.default_locale
  end

  private

  attr_reader :locale_param, :request

  def locale_valid?
    locale_param.present? && I18n.locale_available?(locale_param)
  end
end
