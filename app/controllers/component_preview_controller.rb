class ComponentPreviewController < ViewComponentsController
  if IdentityConfig.store.component_previews_enabled
    include ActionView::Helpers::AssetTagHelper
    helper Lookbook::PreviewHelper
    include Lookbook::PreviewController
    include ScriptHelper

    helper_method :enqueue_component_scripts
    alias_method :enqueue_component_scripts, :render_javascript_pack_once_tags
  end
end
