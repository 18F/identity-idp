# rubocop:disable Rails/HelperInstanceVariable
module ScriptHelper
  MANIFEST_PATH = Rails.root.join('public', 'packs', 'assets-manifest.json').freeze

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

  alias_method :enqueue_component_scripts, :javascript_packs_tag_once

  def render_javascript_pack_once_tags(*names)
    javascript_packs_tag_once(*names) if names.present?
    return if !@scripts

    # RailsI18nWebpackPlugin will generate additional assets suffixed per locale, e.g. `.fr.js`.
    # See: app/javascript/packages/rails-i18n-webpack-plugin/extract-keys-webpack-plugin.js
    regexp_locale_suffix = %r{\.(#{I18n.available_locales.join('|')})\.js$}

    locale_sources, sources = @scripts.flat_map do |name|
      manifest.dig('entrypoints', name, 'assets', 'js')
    end.uniq.compact.partition { |source| regexp_locale_suffix.match?(source) }

    javascript_include_tag(
      *locale_sources.filter { |source| source.end_with? ".#{I18n.locale}.js" },
      *sources,
    )
  end

  private

  def manifest
    @manifest ||= begin
      JSON.parse(File.read(MANIFEST_PATH))
    rescue JSON::ParserError, Errno::ENOENT
      {}
    end
  end
end
# rubocop:enable Rails/HelperInstanceVariable
