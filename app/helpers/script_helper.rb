require 'set'

# rubocop:disable Rails/HelperInstanceVariable
module ScriptHelper
  include Webpacker::Helper

  def javascript_pack_tag_once(name)
    @scripts ||= Set.new
    @scripts.add(name)
  end

  def render_javascript_pack_once_tags
    javascript_pack_tag(*@scripts) if @scripts
  end
end
# rubocop:enable Rails/HelperInstanceVariable
