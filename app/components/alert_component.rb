# frozen_string_literal: true

class AlertComponent < BaseComponent
  TYPES = {
    neutral: 'ads-alert--neutral',
    success: 'ads-alert--success',
    warning: 'ads-alert--warning',
    error: 'ads-alert--error',
  }.freeze

  attr_reader :type, :title, :message, :dismissible, :action, :text_tag, :tag_options

  validates_inclusion_of :type, in: TYPES.keys
  validate :validate_action

  def initialize(
    type: :neutral,
    title: nil,
    message: nil,
    dismissible: true,
    action: nil,
    text_tag: :p,
    **tag_options
  )
    @type = type.to_sym
    @title = title
    @message = message
    @dismissible = dismissible
    @action = action&.to_h&.symbolize_keys
    @text_tag = text_tag
    @tag_options = tag_options
  end

  def content
    @message || super
  end

  def action?
    action.present?
  end

  def action_label
    action[:label]
  end

  def action_url
    action[:url]
  end

  def role
    type == :error ? 'alert' : 'status'
  end

  def css_class
    classes = ['ads-alert', TYPES.fetch(type)]
    classes << 'ads-alert--with-action' if action?
    classes.concat(Array(tag_options[:class]))
    classes
  end

  private

  def validate_action
    return if action.nil?
    return if action_label.present? && action_url.present?

    errors.add(
      :action,
      :incomplete,
      message: 'must include both label and url',
      type: :incomplete,
    )
  end
end
