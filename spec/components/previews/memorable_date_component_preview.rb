class MemorableDateComponentPreview < ViewComponent::Preview
  # @!group Kitchen Sink
  # @display form true
  def default
    render(
      MemorableDateComponent.new(
        form: form_builder,
        name: :date,
        label: 'Date',
        hint: 'Example: 4 28 1986',
      ),
    )
  end
  # @!endgroup

  # @display form true
  # @param label text
  # @param hint text
  # @param min datetime-local
  # @param max datetime-local
  def playground(label: 'Date', min: nil, max: nil, hint: 'Example: 4 28 1986')
    render(
      MemorableDateComponent.new(
        form: form_builder,
        name: :date,
        label: label,
        hint: hint,
        min: min,
        max: max,
      ),
    )
  end

  private

  def form_builder
    SimpleForm::FormBuilder.new(
      '',
      {},
      ActionView::Base.new(
        ActionView::LookupContext.new(ActionController::Base.view_paths),
        {},
        nil,
      ),
      {},
    )
  end
end
