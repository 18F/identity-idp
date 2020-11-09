class LocaleValidator
  def initialize(locale)
    @locale = locale
  end

  def success?
    locale.present? && I18n.locale_available?(locale)
  end

  private

  attr_reader :locale
end
