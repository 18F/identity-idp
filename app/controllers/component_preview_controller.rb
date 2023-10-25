class ComponentPreviewController < ViewComponentsController
  if IdentityConfig.store.component_previews_enabled
    include ActionView::Helpers::AssetTagHelper
    helper Lookbook::PreviewHelper
    include ScriptHelper
    include StylesheetHelper

    helper_method :enqueue_component_scripts
    alias_method :enqueue_component_scripts, :javascript_packs_tag_once

    helper_method :enqueue_component_stylesheets
    alias_method :enqueue_component_stylesheets, :stylesheet_tag_once
  end
end
