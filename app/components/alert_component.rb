# frozen_string_literal: true

class AlertComponent < BaseComponent
  attr_reader :type, :message, :tag_options, :text_tag

  validates_inclusion_of :type, in: [nil, :info, :success, :warning, :error, :emergency]

  def initialize(type: nil, text_tag: 'p', message: nil, **tag_options)
    @type = type
    @message = message
    @tag_options = tag_options
    @text_tag = text_tag
  end

  def role
    if type == :error
      'alert'
    else
      'status'
    end
  end

  def css_class
    ['usa-alert', modifier_css_class, *tag_options[:class]]
  end

  def modifier_css_class
    case type
    when :info
      'usa-alert--info'
    when :success
      'usa-alert--success'
    when :error
      'usa-alert--error'
    when :warning
      'usa-alert--warning'
    when :emergency
      'usa-alert--emergency'
    end
  end

  def content
    @message || super
  end
end
