class IconComponent < BaseComponent
  include AssetHelper

  attr_reader :icon, :tag_options

  def initialize(icon:, **tag_options)
    @icon = icon
    @tag_options = tag_options
  end

  def icon_path
    asset_path("#{design_system_asset_path('img/sprite.svg')}##{icon}")
  end
end
