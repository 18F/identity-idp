# rubocop:disable ModuleLength
# TODO(sbc): Refactor to address rubocop warning
# :reek:DataClump
module FormHelper
  def app_setting_value_field_for(app_setting, f)
    if app_setting.boolean?
      f.input :value, collection: [%w(Enabled 1), %w(Disabled 0)], include_blank: false
    else
      f.input :value
    end
  end

  def block_text_field_tag(name, value, options = {})
    text_field_tag(name, value, options.merge(class: 'block col-12 mb2 field')) +
      form_input_error_messages(name, options)
  end

  def block_date_field_tag(name, value, options = {})
    date_field_tag(name, value, options.merge(class: 'block col-12 mb2 field')) +
      form_input_error_messages(name, options)
  end

  # rubocop:disable MethodLength
  # TODO(sbc): Refactor to address rubocop warning
  def form_input_error_messages(name, options = {})
    content_tag(:div, nil, class: 'bold red mb2', data: { 'errors-for' => name }) do
      if options[:required]
        concat content_tag(
          :div,
          t('forms.value_missing'),
          style: 'display: none',
          data: { 'errors-when' => 'valueMissing' }
        )
      end
      if options[:pattern]
        concat content_tag(
          :div,
          options[:'data-custom-message'] || t('forms.pattern_mismatch'),
          style: 'display: none',
          data: { 'errors-when' => 'patternMismatch' }
        )
      end
    end
  end
  # rubocop:enable MethodLength

  def us_states_territories_select_tag(options = {})
    select_tag(
      'state',
      options_for_select(us_states_territories),
      options.merge(class: 'block col-12 mb2 field')
    ) +
      form_input_error_messages('state', options)
  end

  # rubocop:disable MethodLength, WordArray
  # This method is single statement spread across many lines for readability
  def us_states_territories
    [
      ['--', ''],
      ['Alabama', 'AL'],
      ['Alaska', 'AK'],
      ['American Samoa', 'AS'],
      ['Arizona', 'AZ'],
      ['Arkansas', 'AR'],
      ['Armed Forces Americas', 'AA'],
      ['Armed Forces Others', 'AE'],
      ['Armed Forces Pacific', 'AP'],
      ['California', 'CA'],
      ['Colorado', 'CO'],
      ['Connecticut', 'CT'],
      ['Delaware', 'DE'],
      ['District of Columbia', 'DC'],
      ['Florida', 'FL'],
      ['Georgia', 'GA'],
      ['Guam', 'GU'],
      ['Hawaii', 'HI'],
      ['Idaho', 'ID'],
      ['Illinois', 'IL'],
      ['Indiana', 'IN'],
      ['Iowa', 'IA'],
      ['Kansas', 'KS'],
      ['Kentucky', 'KY'],
      ['Louisiana', 'LA'],
      ['Maine', 'ME'],
      ['Maryland', 'MD'],
      ['Massachusetts', 'MA'],
      ['Michigan', 'MI'],
      ['Minnesota', 'MN'],
      ['Mississippi', 'MS'],
      ['Missouri', 'MO'],
      ['Montana', 'MT'],
      ['Nebraska', 'NE'],
      ['Nevada', 'NV'],
      ['New Hampshire', 'NH'],
      ['New Jersey', 'NJ'],
      ['New Mexico', 'NM'],
      ['New York', 'NY'],
      ['North Carolina', 'NC'],
      ['North Dakota', 'ND'],
      ['Northern Mariana Islands', 'MP'],
      ['Ohio', 'OH'],
      ['Oklahoma', 'OK'],
      ['Oregon', 'OR'],
      ['Pennsylvania', 'PA'],
      ['Puerto Rico', 'PR'],
      ['Rhode Island', 'RI'],
      ['South Carolina', 'SC'],
      ['South Dakota', 'SD'],
      ['Tennessee', 'TN'],
      ['Texas', 'TX'],
      ['United States Minor Outlying Islands', 'UM'],
      ['Utah', 'UT'],
      ['Vermont', 'VT'],
      ['Virgin Islands', 'VI'],
      ['Virginia', 'VA'],
      ['Washington', 'WA'],
      ['West Virginia', 'WV'],
      ['Wisconsin', 'WI'],
      ['Wyoming', 'WY']
    ]
  end
  # rubocop:enable MethodLength, WordArray
end
