class ComponentPreviewController < ViewComponentsController
  include ActionView::Helpers::AssetTagHelper
  helper Lookbook::PreviewHelper
  include Lookbook::PreviewController
  include ScriptHelper

  before_action :override_csp_for_component_preview

  helper_method :enqueue_component_scripts
  alias_method :enqueue_component_scripts, :render_javascript_pack_once_tags

  def override_csp_for_component_preview
    policy = request.content_security_policy

    # In development environments, both ViewComponent and Lookbook explicitly disable CSP. The CSP
    # would be enforced in deployed environments, and we extend it only if present.
    return if policy.blank?

    # Lookbook uses Alpine.js, which relies on unsafe function evaluation.
    # See: https://alpinejs.dev/advanced/csp
    policy.script_src(*policy.script_src, :unsafe_eval)

    # Lookbook displays component previews inside a frame, hosted on the same domain.
    policy.frame_ancestors(*policy.frame_ancestors, :self)
  end
end
