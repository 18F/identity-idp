require 'set'

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

  def javascript_pack_tag_once(name)
    @scripts ||= Set.new
    @scripts.add(name)
    nil
  end

  def render_javascript_pack_once_tags
    javascript_pack_tag(*@scripts) if @scripts
  end
end
# rubocop:enable Rails/HelperInstanceVariable
