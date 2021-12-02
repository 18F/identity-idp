# rubocop:disable Metrics/BlockLength
SimpleForm.setup do |config|
  require Rails.root.join('lib', 'extensions', 'simple_form', 'error_notification')

  config.button_class = 'usa-button'
  config.boolean_label_class = nil
  config.default_form_class = 'margin-top-4'
  config.wrapper_mappings = { inline: :append }

  config.wrappers :base do |b|
    b.use :html5
    b.use :input, class: 'field'
  end

  config.wrappers :vertical_form,
                  tag: 'div',
                  class: 'margin-bottom-4' do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.use :label, class: 'bold'
    b.use :hint,  wrap_with: { tag: 'div', class: 'italic' }
    b.use :input, class: 'block col-12 field', error_class: 'usa-input--error'
    b.use :error, wrap_with: { tag: 'div', class: 'usa-error-message' }
  end

  config.default_wrapper = :vertical_form
end
# rubocop:enable Metrics/BlockLength
