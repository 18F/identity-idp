# frozen_string_literal: true

class CountdownAlertComponent < BaseComponent

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
    content_tag(
      :'lg-countdown-alert',
      content,
      **tag_options,
      class: css_class,
      data: {
        phases: phases.to_json,
        type_classes: type_classes_map.to_json,
        sr_phase_region_id: sr_phase_region_id,
        sr_expiry_region_id: sr_expiry_region_id,
      }.merge(tag_options[:data].to_h),
    )
  end

  def content
    initial = initial_phase
    AlertComponent.new(
      **alert_options,
      type: initial[:type],
      class: alert_css_for(initial[:type]),
    ).with_content(
      safe_join(
        [
          content_tag(:span, initial[:label], 'data-role': 'phase-label'),
          CountdownComponent.new(
            **countdown_options, class: 'display-none',
                                 'aria-hidden': 'true'
          )
                            .render_in(view_context),
        ],
      ),
    ).render_in(view_context)
  end

  private

  def css_class
    Array(tag_options[:class])
  end

  def initial_phase
    remaining_s = [(expiration.to_f - Time.zone.now.to_f).round, 0].max
    asc = phases.sort_by { |p| p[:at_s] }
    asc.find { |p| p[:at_s] >= remaining_s } || asc.last
  end

  def normalize_phases(phases)
    phases.map do |p|
      type = p[:type].to_sym
      { at_s: Integer(p[:at_s]), type:, label: String(p[:label]) }
    end
  end

  def type_classes_map
    {
      'info' => (alert_css_for(:info) - base_alert_classes),
      'warning' => (alert_css_for(:warning) - base_alert_classes),
      'error' => (alert_css_for(:error) - base_alert_classes),
    }
  end

  def alert_css_for(type)
    base_alert_classes + case type
    when :info    then %w[usa-alert--info usa-alert--info-time]
    when :warning then %w[usa-alert--warning]
    when :error   then %w[usa-alert--error]
    else []
    end
  end

  def base_alert_classes
    (%w[usa-alert] + Array(alert_options[:class]).compact)
  end
end
