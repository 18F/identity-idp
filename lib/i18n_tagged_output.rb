require 'i18n_flat_yml_backend'

class I18nTaggedOutput < I18nFlatYmlBackend
  include ActionView::Helpers::TagHelper

  def translate(locale, key, options)
    result = super

    if Rails.application.config.i18n_tag_keys_in_html
      if result.is_a?(Array)
        puts "ARRAY #{result}"
        result
      elsif result.is_a?(Hash)
        puts "HASH #{result}"
        result
      else
        content_tag(:span, data: { i18n: key }) { result }
      end
    else
      result
    end
  end
end
