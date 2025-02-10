# frozen_string_literal: true

module GoBackHelper
  def go_back_path
    referer_string = request.referer
    return if referer_string.blank?
    referer_uri = URI.parse(referer_string)
    return if referer_uri.scheme == 'javascript'
    return unless referer_uri.host == app_host
    extract_path_and_query_from_uri(referer_uri)
  end

  private

  def extract_path_and_query_from_uri(uri)
    [uri.path, uri.query].compact.join('?')
  end

  def app_host
    IdentityConfig.store.domain_name.split(':')[0]
  end
end

ActionView::Base.send :include, GoBackHelper
