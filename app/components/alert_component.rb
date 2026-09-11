# frozen_string_literal: true

class AlertComponent < BaseComponent
  include NDSBucketResolvable

  attr_reader :type, :title, :message, :dismissible, :action, :text_tag, :tag_options

  # nil is the historical default for existing call sites; :neutral is the
  # default used by the NDS look and feel. Both render as a neutral alert.
  validates_inclusion_of :type,
                         in: [nil, :neutral, :info, :success, :warning, :error, :emergency]

  def initialize(
    type: nil,
    title: nil,
    message: nil,
    dismissible: false,
    action: nil,
    text_tag: 'p',
    **tag_options
  )
    @type = type
    @title = title
    @message = message
    @dismissible = dismissible
    @action = action&.to_h&.symbolize_keys
    @text_tag = text_tag
    @tag_options = tag_options
  end

  def role
    type == :error ? 'alert' : 'status'
  end

  def content
    @message || super
  end

  # Legacy bucket: origin/main markup. title:/dismissible:/action: are ignored
  # here; NDSAlertComponent honors them.
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

  private

  # The NDS variant excluded from the render-time flip (see
  # NDSBucketResolvable) so it renders its own markup instead of recursing.
  def nds_variant_class
    NDSAlertComponent
  end

  def nds_delegate
    NDSAlertComponent.new(
      type:, title:, message:, dismissible:, action:, text_tag:,
      **tag_options
    )
  end
end
