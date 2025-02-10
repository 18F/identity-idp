# frozen_string_literal: true

# rubocop:disable Rails/HelperInstanceVariable
module StylesheetHelper
  def stylesheet_tag_once(*names)
    @stylesheets ||= []
    @stylesheets |= names
    nil
  end

  alias_method :enqueue_component_stylesheets, :stylesheet_tag_once

  def render_stylesheet_once_tags(*names)
    stylesheet_tag_once(*names) if names.present?
    return if @stylesheets.blank?
    safe_join(
      @stylesheets.map do |stylesheet|
        url = stylesheet_path(stylesheet)
        AssetPreloadLinker.append(headers: response.headers, as: :style, url:)
        tag.link(rel: :stylesheet, href: url)
      end,
    )
  end
end
# rubocop:enable Rails/HelperInstanceVariable
