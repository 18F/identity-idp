# Use this setup block to configure all options available in SimpleForm.
SimpleForm.setup do |config|
  config.error_notification_class = 'alert alert-danger'
  config.button_class = 'btn btn-default'
  config.boolean_label_class = nil
  config.input_class = 'form-control'

  config.wrappers :vertical_form, tag: 'div', class: 'form-group', error_class: 'has-error' do |b|
    b.use :html5
    b.use :placeholder
    # b.use :tooltip << DISABLED for 508-compliance
    b.optional :maxlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.use :label, class: 'control-label'
    b.wrapper tag: 'div' do
      b.use :input, class: 'form-control'
      b.use :error, wrap_with: { tag: 'span', class: 'error-description'  }
      b.use :hint,  wrap_with: { tag: 'p', class: 'help-block' }
    end
  end

  # Wrappers for forms and inputs using the Bootstrap toolkit.
  # Check the Bootstrap docs (http://getbootstrap.com)
  # to learn about the different styles for forms and inputs,
  # buttons and other elements.
  config.default_wrapper = :vertical_form
end
