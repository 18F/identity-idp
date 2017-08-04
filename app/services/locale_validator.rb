class LocaleValidator
  def initialize(locale)
    @locale = locale
  end

  def success?
    locale.present? && I18n.available_locales.include?(locale.to_sym)
  end

  private

  attr_reader :locale
end
