module URIService
  def self.add_params(original_uri, params)
    return unless original_uri.present?

    URI(original_uri).tap do |uri|
      query = Rack::Utils.parse_nested_query(uri.query).with_indifferent_access
      uri.query = query.merge(params).to_query
    end.to_s
  end
end
