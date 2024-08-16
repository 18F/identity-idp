# frozen_string_literal: true

module UriService
  # @return [Hash]
  def self.params(original_uri)
    uri = URI(original_uri)
    Rack::Utils.parse_nested_query(uri.query).with_indifferent_access
  end

  # @param [#to_s] original_uri
  # @param [Hash, nil] params_to_add
  # @return [URI, nil]
  def self.add_params(original_uri, params_to_add)
    return if original_uri.blank?
    return original_uri if params_to_add.blank?

    URI(original_uri).tap do |uri|
      query = params(uri).merge(params_to_add)
      uri.query = query.empty? ? nil : query.to_query
    end.to_s
  rescue URI::BadURIError, URI::InvalidURIError
    nil
  end
end
