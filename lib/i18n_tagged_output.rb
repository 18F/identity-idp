require 'i18n_flat_yml_backend'

class I18nTaggedOutput < I18nFlatYmlBackend
  include ActionView::Helpers::TagHelper

  def translate(locale, key, options)
    result = super

    if Rails.application.config.i18n_tag_keys_in_html
      content_tag(:span, result, data: { i18n_key: key })
    else
      result
    end
  end
end
