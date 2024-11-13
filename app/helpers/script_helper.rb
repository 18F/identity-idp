# frozen_string_literal: true

# rubocop:disable Rails/HelperInstanceVariable
module ScriptHelper
  def javascript_packs_tag_once(*names, url_params: nil, **attributes)
    @scripts = @scripts.to_h.merge(names.index_with([url_params, attributes]))
    nil
  end

  alias_method :enqueue_component_scripts, :javascript_packs_tag_once

  def render_javascript_pack_once_tags(...)
    capture do
      javascript_packs_tag_once(...)
      return if @scripts.blank?
      concat javascript_assets_tag
      @scripts.each do |name, (url_params, attributes)|
        asset_sources.get_sources(name).each do |source|
          crossorigin = true if local_crossorigin_sources?
          integrity = asset_sources.get_integrity(source)

          if attributes[:preload_links_header] != false
            AssetPreloadLinker.append(response:, as: :script, url: source, crossorigin:, integrity:)
          end

          concat javascript_include_tag(
            UriService.add_params(source, url_params),
            **attributes,
            crossorigin:,
            integrity:,
            preload_links_header: false,
          )
        end
      end
    end
  end

  private

  SAME_ORIGIN_ASSETS = %w[
    sprite.svg
  ].to_set.freeze

  def asset_sources
    Rails.application.config.asset_sources
  end

  def local_crossorigin_sources?
    Rails.env.development? && ENV['WEBPACK_PORT'].present?
  end

  def javascript_assets_tag
    assets = asset_sources.get_assets(*@scripts.keys)

    if assets.present?
      asset_map = assets.index_with { |path| asset_path(path, host: asset_host(path)) }
      content_tag(
        :script,
        asset_map.to_json,
        { type: 'application/json', data: { asset_map: '' } },
        false,
      )
    end
  end

  def asset_host(path)
    if IdentityConfig.store.asset_host.present?
      if SAME_ORIGIN_ASSETS.include?(path)
        IdentityConfig.store.domain_name
      else
        IdentityConfig.store.asset_host
      end
    elsif request
      request.base_url
    end
  end
end
# rubocop:enable Rails/HelperInstanceVariable
