class FormLinkComponent < BaseComponent
  attr_reader :href, :method, :tag_options

  def initialize(href:, method:, **tag_options)
    @href = href
    @method = method
    @tag_options = tag_options
  end
end
