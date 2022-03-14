# rubocop:disable Rails/HelperInstanceVariable
module ScriptHelper
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
    if @scripts.present?
      safe_join(
        [
          javascript_include_tag(*AssetSources.get_sources('polyfill'), nomodule: ''),
          javascript_include_tag(*AssetSources.get_sources(*@scripts)),
        ],
      )
    end
  end
end
# rubocop:enable Rails/HelperInstanceVariable
