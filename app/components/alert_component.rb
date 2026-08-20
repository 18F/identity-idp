# frozen_string_literal: true

class AlertComponent < BaseComponent
  attr_reader :type, :title, :message, :dismissible, :action, :text_tag, :tag_options

  # nil is the historical default for existing call sites; :neutral is the
  # default used by the NDS look and feel. Both render as a neutral alert.
  validates_inclusion_of :type,
                         in: [nil, :neutral, :info, :success, :warning, :error, :emergency]
  validate :validate_action

  def initialize(
    type: nil,
    title: nil,
    message: nil,
    dismissible: true,
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

  # The A/B bucket can only be resolved at render time (helpers are unavailable
  # in #initialize). Callers always instantiate AlertComponent; when the render
  # resolves to the NDS bucket we delegate to NDSAlertComponent. The guard
  # excludes NDSAlertComponent itself so it renders its own markup instead of
  # recursing.
  def before_render
    super
    @render_as_nds = nds_bucket? && !is_a?(NDSAlertComponent)
  end

  private

  def render_as_nds?
    @render_as_nds
  end

  def nds_delegate
    NDSAlertComponent.new(
      type:, title:, message:, dismissible:, action:, text_tag:,
      **tag_options
    )
  end

  # ViewComponent delegates #helpers to the current view context, where
  # nds_layout? is exposed as a controller helper_method. Guard for view
  # contexts without that helper (e.g. mailers). When the bucket can't be
  # resolved because there is no auth context (background jobs, isolated
  # component renders — Devise::MissingWarden), default to the legacy bucket:
  # legacy is the conservative default and rendering must never crash.
  def nds_bucket?
    return false unless helpers.respond_to?(:nds_layout?)

    helpers.nds_layout?
  rescue Devise::MissingWarden
    false
  end

  def validate_action
    return if action.nil?
    return if action[:label].present? && action[:url].present?

    errors.add(:action, :incomplete, message: 'must include both label and url')
  end
end
