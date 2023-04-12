# rubocop:disable Metrics/BlockLength
SimpleForm.setup do |config|
  require Rails.root.join('lib', 'extensions', 'simple_form', 'error_notification')
  require Rails.root.join('lib', 'extensions', 'simple_form', 'components', 'submit_component')

  config.button_class = 'usa-button'
  config.boolean_label_class = nil
  config.boolean_style = :inline
  config.default_form_class = 'margin-top-4'
  config.wrapper_mappings = {
    text: :uswds_text_input,
    string: :uswds_text_input,
    password: :uswds_text_input,
    tel: :uswds_text_input,
    email: :uswds_text_input,
    boolean: :uswds_checkbox,
    radio_buttons: :uswds_bordered_radio_buttons,
    select: :uswds_select,
    hidden: :unwrapped,
  }

  config.wrappers :base do |b|
    b.optional :hint
    b.optional :label
    b.optional :placeholder
    b.use :html5
    b.use :input
  end

  config.wrappers :vertical_form,
                  tag: 'div',
                  class: 'margin-bottom-4' do |b|
    b.use :html5
    b.optional :placeholder
    b.optional :maxlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.optional :label, class: 'usa-label'
    b.optional :hint,  wrap_with: { tag: 'div', class: 'usa-hint' }
    b.use :input, error_class: 'usa-input--error'
    b.use :error, wrap_with: { tag: 'div', class: 'usa-error-message' }
  end

  config.wrappers :unwrapped, wrapper: false do |b|
    b.use :input
  end

  config.wrappers :uswds_text_input, class: 'margin-bottom-4' do |b|
    b.use :html5
    b.optional :placeholder
    b.optional :maxlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.optional :label, class: 'usa-label'
    b.optional :hint,  wrap_with: { tag: 'div', class: 'usa-hint' }
    b.use :input, class: 'usa-input usa-input--big', error_class: 'usa-input--error'
    b.use :error, wrap_with: { tag: 'div', class: 'usa-error-message' }
  end

  config.wrappers :uswds_select do |b|
    b.use :html5
    b.optional :label, class: 'usa-label'
    b.optional :hint,  wrap_with: { tag: 'div', class: 'usa-hint' }
    b.use :input, class: 'usa-select usa-select--big', error_class: 'usa-input--error'
    b.use :error, wrap_with: { tag: 'div', class: 'usa-error-message' }
  end

  config.wrappers :uswds_checkbox do |b|
    b.use :html5
    b.optional :hint, wrap_with: { tag: 'div', class: 'usa-hint' }
    b.use :input, class: 'usa-checkbox__input', error_class: 'usa-input--error'
    b.optional :label, class: 'usa-checkbox__label'
    b.use :error, wrap_with: { tag: 'div', class: 'usa-error-message' }
  end

  # Helper proc to define different types of radio button wrappers
  radio_button_builder = proc do |name, bordered|
    item_label_class = 'usa-radio__label width-full' +
                       (bordered ? ' text-no-wrap' : ' margin-top-0')
    legend_class = 'usa-label' + (bordered ? '' : ' margin-bottom-2')
    input_class = 'usa-radio__input' + (bordered ? ' usa-radio__input--bordered' : '')

    config.wrappers name,
                    tag: 'fieldset',
                    wrapper_class: 'usa-fieldset margin-bottom-4',
                    item_wrapper_tag: nil,
                    item_label_class: item_label_class do |b|
      b.use :html5
      b.wrapper :legend, tag: 'legend', class: legend_class do |ba|
        ba.use :label_text
      end
      b.optional :hint, wrap_with: { tag: 'div', class: 'usa-hint margin-bottom-05' }
      b.wrapper :grid_row, tag: :div, class: 'grid-row margin-bottom-neg-1' do |gr|
        gr.wrapper :grid_column_radios, tag: :div, class: 'grid-col-fill' do |gc|
          gc.wrapper :column_wrapper, tag: :div, class: 'display-inline-block minw-full' do |cr|
            cr.use :input, class: input_class
          end
        end
        if bordered
          gr.wrapper(:grid_column_gap, tag: :div, class: 'grid-col-4 tablet:grid-col-6') {}
        end
      end
      b.use :error, wrap_with: { tag: 'div', class: 'usa-error-message' }
    end
  end

  # Define regular and bordered radio button wrappers
  radio_button_builder.call(:uswds_radio_buttons, false)
  radio_button_builder.call(:uswds_bordered_radio_buttons, true)

  config.default_wrapper = :vertical_form
end
# rubocop:enable Metrics/BlockLength
