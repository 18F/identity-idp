class CancellationPresenter
  include Rails.application.routes.url_helpers

  attr_reader :referer, :url_options

  def initialize(referer:, url_options:)
    @referer = referer
    @url_options = url_options
  end

  def go_back_path
    referer_path || authentication_methods_setup_path
  end

  private

  def referer_path
    return if referer.blank?
    referer_uri = URI.parse(referer)
    return if referer_uri.scheme == 'javascript'
    return unless referer_uri.host == IdentityConfig.store.domain_name.split(':')[0]
    extract_path_and_query_from_uri(referer_uri)
  end

  def extract_path_and_query_from_uri(uri)
    [uri.path, uri.query].compact.join('?')
  end
end
