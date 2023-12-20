class ComponentPreviewController < ViewComponentsController
  if IdentityConfig.store.component_previews_enabled
    include ActionView::Helpers::AssetTagHelper
    helper Lookbook::PreviewHelper
    include ScriptHelper
    include StylesheetHelper

    helper_method :enqueue_component_scripts
    alias_method :enqueue_component_scripts, :render_javascript_pack_once_tags

    helper_method :enqueue_component_stylesheets
    alias_method :enqueue_component_stylesheets, :render_stylesheet_once_tags
  end
end
