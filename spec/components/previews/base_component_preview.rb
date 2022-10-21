class BaseComponentPreview < ViewComponent::Preview
  private

  def form_builder
    @form_builder ||= SimpleForm::FormBuilder.new(
      '',
      form_instance,
      ActionView::Base.new(
        ActionView::LookupContext.new(ActionController::Base.view_paths),
        {},
        nil,
      ),
      {},
    )
  end

  def form_instance
    nil
  end

  # rubocop:disable Layout/LineLength
  def example_long_content
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc et tincidunt libero, quis eleifend dui. Quisque dui velit, euismod ac arcu in, vehicula suscipit dui. Vivamus sed justo justo. Nunc a feugiat libero. Nulla dapibus blandit nisl, ac ultrices sapien dapibus ut. Vivamus convallis elementum mi pulvinar elementum. Quisque at aliquet nibh. Donec sed magna ut ipsum auctor dapibus. Proin leo metus, placerat eu finibus sed, consequat eu urna. Nunc tristique purus sollicitudin, luctus nisi eu, commodo tortor. Praesent mattis dictum diam ac sodales.'
  end
  # rubocop:enable Layout/LineLength
end
