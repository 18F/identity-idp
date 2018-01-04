class LinkLocaleResolver
  def self.locale
    locale = I18n.locale
    locale == I18n.default_locale ? nil : locale
  end
end
