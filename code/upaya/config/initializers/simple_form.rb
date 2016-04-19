SimpleForm.setup do |config|
  config.button_class = 'usa-button'
  config.boolean_label_class = nil
  config.input_class = 'field'

  config.wrappers :vertical_form, tag: 'div', error_class: 'has-error' do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.use :label
    b.use :input
  end

  config.default_wrapper = :vertical_form
end
