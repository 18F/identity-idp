require 'set'

# rubocop:disable Rails/HelperInstanceVariable
module ScriptHelper
  def javascript_pack_tag_once(name)
    @scripts ||= Set.new
    @scripts.add(name)
  end

  # rubocop:disable Rails/OutputSafety
  def print_javascript_pack_once_tags
    return unless @scripts
    @scripts.map { |name| javascript_pack_tag(name) }.join('').html_safe
  end
  # rubocop:enable Rails/OutputSafety
end
# rubocop:enable Rails/HelperInstanceVariable
