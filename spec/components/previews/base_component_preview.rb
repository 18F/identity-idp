class BaseComponentPreview < ViewComponent::Preview
  private

  def form_builder
    @form_builder ||= SimpleForm::FormBuilder.new(
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
