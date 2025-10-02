# frozen_string_literal: true

class CountdownPhaseAlertComponent < BaseComponent
  attr_reader :expiration, :phases, :alert_options, :countdown_options,
              :sr_phase_region_id, :sr_expiry_region_id, :tag_options

  def initialize(
    expiration:,
    phases:,
    alert_options: {},
    countdown_options: {},
    sr_phase_region_id: nil,
    sr_expiry_region_id: nil,
    **tag_options
  )
    @expiration = expiration
    @phases = normalize_phases(phases)
    @alert_options = alert_options
    @countdown_options = { expiration:, start_immediately: true }.merge(countdown_options)
    @sr_phase_region_id = sr_phase_region_id
    @sr_expiry_region_id = sr_expiry_region_id
    @tag_options = tag_options
  end

  def call
    base = base_alert_classes.join(' ')

    content_tag(
      :'lg-countdown-alert',
      content(base),
      **tag_options,
      class: css_class,
      data: {
        phases: phases.to_json,
        base_classes: base,
        sr_phase_region_id: sr_phase_region_id,
        sr_expiry_region_id: sr_expiry_region_id,
      }.merge(tag_options[:data].to_h),
    )
  end

  def content(base_classes)
    initial = initial_phase
    AlertComponent.new(
      **alert_options,
      class: [base_classes, initial[:classes]].join(' ').squeeze(' '),
    ).with_content(
      safe_join(
        [
          content_tag(:span, initial[:label], 'data-role': 'phase-label'),
          CountdownComponent.new(
            **countdown_options, class: 'display-none', 'aria-hidden': 'true'
          ).render_in(view_context),
        ],
      ),
    ).render_in(view_context)
  end

  private

  def css_class
    Array(tag_options[:class])
  end

  def initial_phase
    phases.max_by { |p| p[:at_s] }
  end

  def normalize_phases(phases)
    Array(phases).map { |p|
      {
        at_s: Integer(p[:at_s]),
        classes: String(p[:classes]).strip,
        label: String(p[:label]),
      }
    }.sort_by { |p| p[:at_s] }
  end

  def base_alert_classes
    (%w[usa-alert] + Array(alert_options[:class]).compact)
  end
end
