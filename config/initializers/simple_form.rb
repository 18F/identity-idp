# rubocop:disable Metrics/BlockLength
SimpleForm.setup do |config|
  require Rails.root.join('lib', 'extensions', 'simple_form', 'error_notification')
  require Rails.root.join('lib', 'extensions', 'simple_form', 'components', 'submit_component')

  config.button_class = 'usa-button'
  config.boolean_label_class = nil
  config.boolean_style = :inline
  config.default_form_class = 'margin-top-4'
  config.wrapper_mappings = {
    boolean: :uswds_checkbox,
    radio_buttons: :uswds_bordered_radio_buttons,
    hidden: :unwrapped,
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

  config.wrappers :unwrapped, wrapper: false do |b|
    b.use :input
  end

  config.wrappers :uswds_checkbox do |b|
    b.use :html5
    b.use :hint,  wrap_with: { tag: 'div', class: 'usa-hint' }
    b.use :input, class: 'usa-checkbox__input', error_class: 'usa-input--error'
    b.use :label, class: 'usa-checkbox__label'
    b.use :error, wrap_with: { tag: 'div', class: 'usa-error-message' }
  end

  config.wrappers :err do |b|
    b.use :input, class: 'usa-input', error_class: 'usa-input--error'
    b.use :error, wrap_with: { tag: 'div', class: 'usa-error-message' }
  end

  config.wrappers :uswds_memorable_date, 
    tag: 'fieldset',
    wrapper_class: 'usa-fieldset' do |b|
    b.wrapper :legend, tag: 'legend', class: 'usa-legend' do |ba|
      ba.use :label_text
    end
    b.use :hint,  wrap_with: { tag: 'span', class: 'usa-hint' }
    b.wrapper :memorable_date, tag: 'div', class:'usa-memorable-date' do |md|
      md.wrapper :memorable_month, tag: 'div', class: 'usa-form-group usa-form-group--month' do |mdl|
        mdl.wrapper :label, tag: 'label', class: 'usa-label' do |ba|
          ba.use :month_label
        end
      end
      md.wrapper :memorable_day, tag: 'div', class: 'usa-form-group usa-form-group--day' do |mdd|
        mdd.wrapper :label, tag: 'label', class: 'usa-label' do |ba|
          ba.use :day_label
        end
      end
      md.wrapper :memorable_year, tag: 'div', class: 'usa-form-group usa-form-group--year' do |mdy|
        mdy.wrapper :label, tag: 'label', class: 'usa-label' do |ba|
          ba.use :year_label
        end
      end
    end
    b.use :input, class: 'usa-input', error_class: 'usa-input--error', type: 'number'
    b.use :error,  wrap_with: { tag: 'div', class: 'usa-error-message' }
  end

  # Helper proc to define different types of radio button wrappers
  radio_button_builder = proc do |name, bordered|
    item_label_class = 'usa-radio__label width-full text-no-wrap' +
                       (bordered ? '' : ' margin-top-0')
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
      b.use :hint, wrap_with: { tag: 'div', class: 'usa-hint margin-bottom-05' }
      b.wrapper :grid_row, tag: :div, class: 'grid-row margin-bottom-neg-1' do |gr|
        gr.wrapper :grid_column_radios, tag: :div, class: 'grid-col-fill' do |gc|
          gc.wrapper :column_wrapper, tag: :div, class: 'display-inline-block minw-full' do |cr|
            cr.use :input, class: input_class
          end
        end
        gr.wrapper(:grid_column_gap, tag: :div, class: 'grid-col-4 tablet:grid-col-6') {}
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
