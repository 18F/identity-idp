module AssetHelper
  DESIGN_SYSTEM_ASSET_ROOT = '@18f/identity-design-system/dist/assets'.freeze

  def design_system_asset_path(path)
    File.join(DESIGN_SYSTEM_ASSET_ROOT, path)
  end
end
