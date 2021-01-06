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
    if (prepend)
      @scripts = names | @scripts
    else
      @scripts = @scripts | names
    end
    nil
  end

  def render_javascript_pack_once_tags
    javascript_packs_with_chunks_tag(*@scripts) if @scripts
  end
end
# rubocop:enable Rails/HelperInstanceVariable
