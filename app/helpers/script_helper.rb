# rubocop:disable Rails/HelperInstanceVariable
module ScriptHelper
  include Webpacker::Helper

  def javascript_include_tag_without_preload(*sources)
    original_preload_links_header = ActionView::Helpers::AssetTagHelper.preload_links_header
    ActionView::Helpers::AssetTagHelper.preload_links_header = false
    tag = javascript_include_tag(*sources)
    ActionView::Helpers::AssetTagHelper.preload_links_header = original_preload_links_header
    tag
  end

  def javascript_packs_tag_once(*names, prepend: false)
    @scripts ||= []
    if prepend
      @scripts = names | @scripts
    else
      @scripts |= names
    end
    nil
  end

  alias_method :render_component_script, :javascript_packs_tag_once

  def render_javascript_pack_once_tags
    return if !@scripts

    # RailsI18nWebpackPlugin will generate additional assets suffixed per locale, e.g. `.fr.js`.
    # See: app/javascript/packages/rails-i18n-webpack-plugin/extract-keys-webpack-plugin.js
    regexp_locale_suffix = %r{\.(#{I18n.available_locales.join('|')})\.js$}

    locale_sources, sources = @scripts.flat_map do |name|
      current_webpacker_instance.manifest.lookup_pack_with_chunks!(name, type: :javascript)
    end.uniq.partition { |source| regexp_locale_suffix.match?(source) }

    javascript_include_tag(
      *locale_sources.filter { |source| source.end_with? ".#{I18n.locale}.js" },
      *sources,
    )
  end
end
# rubocop:enable Rails/HelperInstanceVariable
