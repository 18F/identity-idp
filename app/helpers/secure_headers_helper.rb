module SecureHeadersHelper
  def backwards_compatible_javascript_tag(*args, **opts, &block)
    if FeatureManagement.rails_csp_tooling_enabled?
      javascript_tag *args, **opts.merge(nonce: true), &block
    else
      nonced_javascript_tag *args, **opts, &block
    end
  end
end
