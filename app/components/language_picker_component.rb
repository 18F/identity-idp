class LanguagePickerComponent < BaseComponent
  attr_reader :url_generator, :tag_options

  def initialize(url_generator: method(:url_for), **tag_options)
    @url_generator = url_generator
    @tag_options = tag_options
  end

  def css_class
    ['language-picker', 'usa-accordion', *tag_options[:class]]
  end

  def sanitized_request_params
    request.query_parameters.slice(:request_id)
  end
end
