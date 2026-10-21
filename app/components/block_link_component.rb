# frozen_string_literal: true

class BlockLinkComponent < BaseComponent
  attr_reader :url, :action, :new_tab, :tag_options, :component

  alias_method :new_tab?, :new_tab

  ALLOWED_URL_SCHEMES = %w[http https].freeze

  def initialize(url: '#', component: nil, new_tab: false, **tag_options)
    @valid = validate_url_scheme(url)
    @url = url
    @component = component
    @new_tab = new_tab
    @tag_options = tag_options
  end

  def css_class
    classes = ['usa-link', 'block-link', *tag_options[:class]]
    classes << 'usa-link--external' if new_tab?
    classes
  end

  def target
    '_blank' if new_tab?
  end

  def validate_url_scheme(url)
    scheme = URI(url.strip).scheme

    return true if scheme.nil? || ALLOWED_URL_SCHEMES.include?(scheme.downcase)

    NewRelic::Agent.notice_error(
      ArgumentError.new("Unsafe URL scheme for BlockLinkComponent: #{scheme}"),
    )
    return false
  rescue URI::InvalidURIError
    NewRelic::Agent.notice_error(
      ArgumentError.new("Invalid URL for BlockLinkComponent: #{url}"),
    )
    return false
  end

  def wrapper(&block)
    if !@valid
      render template: 'pages/not_acceptable', layout: false, status: :not_acceptable,
             formats: :html
    elsif component
      render component.new(href: url, class: css_class), &block
    else
      action = tag.method(:a)
      action.call(**tag_options, href: url, class: css_class, target:, &block)
    end
  end
end
