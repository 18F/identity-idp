# frozen_string_literal: true

# NDS bucket alert. Honors title:/dismissible:/action: and emits the NDS alert
# structure (dismiss mount wrapper, heading, action/close buttons) on standard
# USWDS selectors so the NDS overlay styles them. Rendered by AlertComponent
# (the caller-facing entry point) when the render resolves to the NDS bucket;
# not instantiated by call sites directly. Deleting this file + the
# render_as_nds delegation in AlertComponent removes the experiment.
class NDSAlertComponent < AlertComponent
  # Type -> USWDS modifier map for the NDS bucket. neutral (the NDS default)
  # maps to --info.
  NDS_MODIFIERS = {
    neutral: 'usa-alert--info',
    info: 'usa-alert--info',
    success: 'usa-alert--success',
    warning: 'usa-alert--warning',
    error: 'usa-alert--error',
    emergency: 'usa-alert--emergency',
  }.freeze

  validate :validate_action, unless: -> { action.blank? }

  def css_class
    classes = ['usa-alert', NDS_MODIFIERS.fetch(type || :neutral)]
    classes << 'usa-alert--with-action' if action?
    classes.concat(Array(tag_options[:class]))
    classes
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

  private

  def validate_action
    return if action[:label].present? && action[:url].present?

    errors.add(:action, :incomplete, message: 'must include both label and url')
  end
end
