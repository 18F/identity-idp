# frozen_string_literal: true

class CardComponent < BaseComponent
  PADDINGS = {
    default: nil,
    compact: 'ads-card--compact',
  }.freeze

  renders_one :trailing

  attr_reader :url, :method, :button, :padding, :tag_options

  alias_method :button?, :button
  validate :validate_action_mode

  def initialize(url: nil, method: nil, button: false, padding: :default, **tag_options)
    @url = url
    @method = method
    @button = button
    @padding = padding.to_sym
    @tag_options = tag_options
  end

  def interactive?
    url.present? || button?
  end

  def css_class
    classes = ['ads-card', PADDINGS.fetch(padding), *tag_options[:class]]
    classes << 'ads-card--interactive' if interactive?
    classes.compact
  end

  private

  def action
    @action ||= begin
      if url
        if method && method != :get
          lambda do |**opts, &block|
            button_to(url, method:, form_class: 'ads-card-form', **opts, &block)
          end
        else
          ->(**opts, &block) { link_to(url, **opts, &block) }
        end
      elsif button?
        ->(**opts, &block) { button_tag(**opts, &block) }
      else
        ->(**opts, &block) { content_tag(:div, **opts, &block) }
      end
    end
  end

  def wrapper_options
    options = tag_options.except(:class)
    options[:type] ||= :button if button? && !url
    options
  end

  def validate_action_mode
    if button? && url.present?
      errors.add(
        :button,
        :conflicts_with_url,
        message: 'cannot be combined with url',
        type: :conflicts_with_url,
      )
    end
    if method.present? && url.blank?
      errors.add(
        :method,
        :missing_url,
        message: 'requires a url',
        type: :missing_url,
      )
    end
  end
end
