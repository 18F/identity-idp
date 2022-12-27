module CspHelper
  def add_document_capture_image_urls_to_csp(request, urls)
    cleaned_urls = urls.compact.map do |url|
      URI(url).tap { |uri| uri.query = nil }.to_s
    end

    policy = request.content_security_policy.clone
    policy.connect_src(*policy.connect_src, *cleaned_urls)
    request.content_security_policy = policy
  end
end
