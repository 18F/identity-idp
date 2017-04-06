class Url
  include ActionView::Helpers::UrlHelper

  attr_reader :link_text, :path_name, :params

  def initialize(link_text:, path_name:, params: {})
    @link_text = link_text
    @path_name = path_name
    @params = params
  end

  def to_s
    link_to link_text, url
  end

  private

  def url
    Rails.application.routes.url_helpers.send("#{path_name}_path", params)
  end
end
