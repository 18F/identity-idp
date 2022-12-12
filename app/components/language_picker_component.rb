class LanguagePickerComponent < BaseComponent
  attr_reader :tag_options

  def initialize(**tag_options)
    @tag_options = tag_options
  end

  def css_class
    ['language-picker', 'usa-accordion', *tag_options[:class]]
  end

  def locale_urls
    I18n.available_locales.index_with { |locale| "/#{locale}#{fullpath_without_locale}" }
  end

  private

  def fullpath_without_locale
    @fullpath_without_locale ||= begin
      path = request.fullpath
      path = path.slice(params[:locale].size + 1..) if params[:locale].present?
      path
    end
  end
end
