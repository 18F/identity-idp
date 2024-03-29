# frozen_string_literal: true

class LinkLocaleResolver
  def self.locale
    locale = I18n.locale
    locale == I18n.default_locale ? nil : locale
  end

  def self.locale_options
    if I18n.locale == I18n.default_locale
      {}
    else
      { locale: I18n.locale }
    end
  end
end
