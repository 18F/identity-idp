# frozen_string_literal: true

module ScriptHelper
  def javascript_packs_tag_once(*names, **attributes)
    scripts = RequestStore.store[:scripts]
    if scripts
      RequestStore.store[:scripts].merge!(names.index_with(attributes))
    else
      RequestStore.store[:scripts] = names.index_with(attributes)
    end
    nil
  end

  alias_method :enqueue_component_scripts, :javascript_packs_tag_once

  def render_javascript_pack_once_tags(...)
    capture do
      javascript_packs_tag_once(...)
      return if RequestStore.store[:scripts].blank?
      concat javascript_assets_tag
      RequestStore.store[:scripts].each do |name, attributes|
        asset_sources.get_sources(name).each do |source|
          concat javascript_include_tag(
            source,
            **attributes,
            crossorigin: local_crossorigin_sources? ? true : nil,
            integrity: asset_sources.get_integrity(source),
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
    assets = asset_sources.get_assets(*RequestStore.store[:scripts].keys)

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
