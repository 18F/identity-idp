# frozen_string_literal: true

# NDS step indicator. In the nds bucket this renders NDS::ProgressComponent
# (the pill stepper) in place of the legacy lg-step-indicator dots.
# Instantiated by StepIndicatorComponent when a render resolves to the nds
# bucket; call sites always use StepIndicatorComponent directly.
#
# Steps map 1:1 to progress pills: each step's localized title becomes a pill
# label and current_step's name resolves to the active pill index. Placement
# is in-body at the step indicator's spot.
class NDSStepIndicatorComponent < StepIndicatorComponent
  def progress_component
    NDS::ProgressComponent.new(
      steps: step_titles,
      current_step: current_step_index,
      label: t('step_indicator.accessible_label'),
      **tag_options,
    )
  end

  private

  def step_titles
    @steps.map { |step| step_title(step) }
  end

  def current_step_index
    @steps.index { |step| step[:name] == current_step } || 0
  end
end
