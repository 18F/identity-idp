# frozen_string_literal: true

# Presentational multi-step header progress (pills + optional substep counter).
# Resolve positions via {ProgressHelper#ads_chrome_progress} (sign-up map or IDV partial).
class ProgressComponent < BaseComponent
  attr_reader :steps,
              :current_step,
              :current_substep,
              :substep_count,
              :tag_options

  validates :steps, presence: true
  validate :validate_current_step
  validate :validate_substep

  def initialize(
    steps:,
    current_step:,
    label: nil,
    current_substep: nil,
    substep_count: nil,
    **tag_options
  )
    @steps = steps
    @current_step = current_step.to_i
    @label = label
    @current_substep = current_substep&.to_i
    @substep_count = substep_count&.to_i
    @tag_options = tag_options
  end

  def label
    @label.presence || I18n.t('step_indicator.accessible_label')
  end

  def css_class
    ['ads-progress', *tag_options[:class]]
  end

  def step_options(index)
    {
      class: 'ads-progress__step',
      data: { complete: (true if completed_step?(index)) }.compact,
      aria: { current: ('step' if active_step?(index)) }.compact,
    }
  end

  def show_substep_counter?(index)
    active_step?(index) && current_substep.present? && substep_count.present?
  end

  def active_step?(index)
    index == current_step
  end

  def completed_step?(index)
    index < current_step
  end

  # Complete / not-complete for SR (current uses aria-current only).
  def status_sr_text(index)
    return I18n.t('step_indicator.status.complete') if completed_step?(index)
    return if active_step?(index)

    I18n.t('step_indicator.status.not_complete')
  end

  def substep_sr_text(index)
    return unless show_substep_counter?(index)

    I18n.t(
      'step_indicator.substep',
      current: current_substep,
      total: substep_count,
    )
  end

  private

  def validate_current_step
    return if steps.blank?
    return if current_step >= 0 && current_step < steps.length

    errors.add(
      :current_step,
      :outside_steps,
      message: 'must reference an existing step',
      type: :outside_steps,
    )
  end

  def validate_substep
    return if current_substep.nil? && substep_count.nil?
    return if current_substep.to_i.between?(1, substep_count.to_i)

    errors.add(
      :current_substep,
      :outside_substeps,
      message: 'must reference an existing substep',
      type: :outside_substeps,
    )
  end
end
