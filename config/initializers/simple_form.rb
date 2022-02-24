# rubocop:disable Metrics/BlockLength
SimpleForm.setup do |config|
  require Rails.root.join('lib', 'extensions', 'simple_form', 'error_notification')

  config.button_class = 'usa-button'
  config.boolean_label_class = nil
  config.boolean_style = :inline
  config.default_form_class = 'margin-top-4'
  config.wrapper_mappings = {
    boolean: :uswds_checkbox,
    radio_buttons: :uswds_radio_buttons,
  }

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
    b.use :label, class: 'text-bold'
    b.use :hint,  wrap_with: { tag: 'div', class: 'usa-hint' }
    b.use :input, class: 'display-block width-full field', error_class: 'usa-input--error'
    b.use :error, wrap_with: { tag: 'div', class: 'usa-error-message' }
  end

  config.wrappers :uswds_checkbox do |b|
    b.use :html5
    b.use :hint,  wrap_with: { tag: 'div', class: 'usa-hint' }
    b.use :input, class: 'usa-checkbox__input', error_class: 'usa-input--error'
    b.use :label, class: 'usa-checkbox__label'
    b.use :error, wrap_with: { tag: 'div', class: 'usa-error-message' }
  end

  config.wrappers :uswds_radio_buttons,
                  tag: 'fieldset',
                  wrapper_class: 'usa-fieldset margin-bottom-4',
                  item_wrapper_tag: nil,
                  item_label_class: 'usa-radio__label width-full text-no-wrap' do |b|
    b.use :html5
    b.wrapper :legend, tag: 'legend', class: 'usa-label' do |ba|
      ba.use :label_text
    end
    b.use :hint, wrap_with: { tag: 'div', class: 'usa-hint margin-bottom-05' }
    b.wrapper :grid_row, tag: :div, class: 'grid-row margin-bottom-neg-1' do |gr|
      gr.wrapper :grid_column_radios, tag: :div, class: 'grid-col-fill' do |gc|
        gc.wrapper :column_wrapper, tag: :div, class: 'display-inline-block minw-full' do |cr|
          cr.use :input, class: 'usa-radio__input usa-radio__input--bordered'
        end
      end
      gr.wrapper(:grid_column_gap, tag: :div, class: 'grid-col-4 tablet:grid-col-6') {}
    end
    b.use :error, wrap_with: { tag: 'div', class: 'usa-error-message' }
  end

  config.default_wrapper = :vertical_form
end
# rubocop:enable Metrics/BlockLength
