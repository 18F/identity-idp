class ProgressComponentPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  # @param current_step select { choices: [0, 1, 2] }
  # @param show_substeps toggle
  def workbench(current_step: 1, show_substeps: true)
    steps = ['Create account', 'Secure account', 'Connect service']

    render(
      ProgressComponent.new(
        steps:,
        current_step: current_step.to_i,
        current_substep: show_substeps ? 1 : nil,
        substep_count: show_substeps ? 2 : nil,
      ),
    )
  end
end
