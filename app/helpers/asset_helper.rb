module AssetHelper
  DESIGN_SYSTEM_ASSET_ROOT = 'identity-style-guide/dist/assets'.freeze

  def design_system_asset_path(path)
    File.join(DESIGN_SYSTEM_ASSET_ROOT, path)
  end
end
