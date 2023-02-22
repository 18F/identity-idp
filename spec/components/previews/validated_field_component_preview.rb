class ValidatedFieldComponentPreview < BaseComponentPreview
  # @!group Preview
  # @display form true
  def text_field
    render(
      ValidatedFieldComponent.new(
        form: form_builder,
        name: :text_field,
        label: 'Text Field',
        required: false,
      ),
    )
  end

  def required_text_field
    render(
      ValidatedFieldComponent.new(
        form: form_builder,
        name: :required_text_field,
        label: 'Required Text Field',
        required: true,
      ),
    )
  end

  def email_address
    render(
      ValidatedFieldComponent.new(
        form: form_builder,
        name: :email_address,
        label: 'Email Address',
        as: :email,
      ),
    )
  end

  def required_checkbox
    render(
      ValidatedFieldComponent.new(
        form: form_builder,
        name: :required_checkbox,
        label: 'Required Checkbox',
        as: :boolean,
        required: true,
      ),
    )
  end
  # @!endgroup

  # @display form true
  # @param label text
  # @param required toggle
  # @param input_type select [~,String,Email,Boolean]
  def workbench(label: 'Input', required: true, input_type: 'String')
    render(
      ValidatedFieldComponent.new(
        form: form_builder,
        name: :input,
        label:,
        required:,
        as: input_type.underscore.tr(' ', '_').to_sym,
      ),
    )
  end
end
