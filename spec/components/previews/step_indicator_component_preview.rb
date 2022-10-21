class StepIndicatorComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render StepIndicatorComponent.new(
      steps: [
        { name: :first_step, title: 'First Step' },
        { name: :second_step, title: 'Second Step' },
        { name: :third_step, title: 'Third Step' },
        { name: :fourth_step, title: 'Fourth Step' },
      ],
      current_step: :second,
    )
  end
  # @!endgroup

  # @param current_step select [~,First Step,Second Step,Third Step,Fourth Step]
  def workbench(current_step: 'Second Step')
    render StepIndicatorComponent.new(
      steps: [
        { name: :first_step, title: 'First Step' },
        { name: :second_step, title: 'Second Step' },
        { name: :third_step, title: 'Third Step' },
        { name: :fourth_step, title: 'Fourth Step' },
      ],
      current_step: current_step.underscore.tr(' ', '_').to_sym,
    )
  end
end
