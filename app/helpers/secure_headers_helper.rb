module SecureHeadersHelper
  def backwards_compatible_javascript_tag(*args, **opts, &block)
    if FeatureManagement.rails_csp_tooling_enabled?
      javascript_tag(*args, opts.merge(nonce: true), &block)
    else
      nonced_javascript_tag(*args, **opts, &block)
    end
  end

  def add_document_capture_image_urls_to_csp(request, urls)
    cleaned_urls = urls.compact.map do |url|
      URI(url).tap { |uri| uri.query = nil }.to_s
    end

    if FeatureManagement.rails_csp_tooling_enabled?
      add_document_capture_image_urls_to_csp_with_rails_csp_tooling(request, cleaned_urls)
    else
      add_document_capture_image_urls_to_csp_with_secure_headers(request, cleaned_urls)
    end
  end

  def add_document_capture_image_urls_to_csp_with_secure_headers(request, urls)
    SecureHeaders.append_content_security_policy_directives(
      request,
      connect_src: urls,
    )
  end

  def add_document_capture_image_urls_to_csp_with_rails_csp_tooling(request, urls)
    policy = request.content_security_policy
    policy.connect_src(*policy.connect_src, *urls)
    request.content_security_policy = policy
  end
end
