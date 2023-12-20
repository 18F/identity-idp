class ComponentPreviewController < ViewComponentsController
  DEV_FRAME_ANCESTORS = [
    'https://developers.login.gov',
  ].freeze

  if IdentityConfig.store.component_previews_enabled
    include ActionView::Helpers::AssetTagHelper
    helper Lookbook::PreviewHelper
    include ScriptHelper
    include StylesheetHelper

    before_action :override_frame_ancestors_csp

    def override_frame_ancestors_csp
      return if Identity::Hostdata.env != 'dev'
      policy = current_content_security_policy
      policy.frame_ancestors(*policy.frame_ancestors, *DEV_FRAME_ANCESTORS)
      request.content_security_policy = policy
    end

    helper_method :enqueue_component_scripts
    alias_method :enqueue_component_scripts, :render_javascript_pack_once_tags

    helper_method :enqueue_component_stylesheets
    alias_method :enqueue_component_stylesheets, :render_stylesheet_once_tags
  end
end
