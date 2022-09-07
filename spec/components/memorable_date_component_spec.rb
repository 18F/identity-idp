require 'rails_helper'

RSpec.describe MemorableDateComponent, type: :component do
  include SimpleForm::ActionViewExtensions::FormHelper

  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, controller) }
  let(:form_object) { Date.new }
  let(:form_builder) do
    SimpleForm::FormBuilder.new('MemorableDate', form_object, view_context, {})
  end
  let(:name) { 'test-name' }
  let(:month) { 12 }
  let(:day) { 1 }
  let(:year) { 1990 }
  let(:min) { '1800-01-01' }
  let(:max) { '2100-12-31' }
  let(:hint) { 'hint' }
  let(:label) { 'label' }
  let(:error_messages) { nil }
  let(:range_errors) { nil }
  let(:required) { nil }
  let(:tag_options) { {} }
  let(:options) do
    {
      name: name,
      month: month,
      day: day,
      year: year,
      min: Date.parse(min),
      max: Date.parse(max),
      hint: hint,
      label: label,
      form: form_builder,
      required: required,
      error_messages: error_messages,
      range_errors: range_errors,
      **tag_options,
    }.compact
  end

  subject(:rendered) do
    sut = render_inline(described_class.new(**options))
    render_inline(ButtonComponent.new type: :submit)
    sut
  end

  it 'renders a memorable date component with all necessary elements' do
    expect(rendered).to have_css('.usa-label')
    expect(rendered).to have_css('.usa-hint')
    expect(rendered).to have_css(
      'lg-memorable-date script.memorable-date__error-strings',
      visible: false,
    )
    expect(rendered).to have_css('lg-memorable-date lg-validated-field input.memorable-date__month')
    expect(rendered).to have_css('lg-memorable-date lg-validated-field input.memorable-date__day')
    expect(rendered).to have_css('lg-memorable-date lg-validated-field input.memorable-date__year')
  end

  it 'sets the label' do
    expect(rendered).to have_css('.usa-label', text: label)
  end

  it 'sets the hint' do
    expect(rendered).to have_css('.usa-hint', text: hint)
  end

  it 'shows month, day, and year labels corresponding to inputs' do
    expect(rendered).to have_css(
      'label[for="MemorableDate_test-name_month"]',
      text: t('components.memorable_date.month'),
    )
    expect(rendered).to have_css(
      'label[for="MemorableDate_test-name_day"]',
      text: t('components.memorable_date.day'),
    )
    expect(rendered).to have_css(
      'label[for="MemorableDate_test-name_year"]',
      text: t('components.memorable_date.year'),
    )

    expect(rendered).to have_css('input.memorable-date__month#MemorableDate_test-name_month')
    expect(rendered).to have_css('input.memorable-date__day#MemorableDate_test-name_day')
    expect(rendered).to have_css('input.memorable-date__year#MemorableDate_test-name_year')
  end

  it 'sets the date field values' do
    expect(rendered).to have_css(".memorable-date__month[value=\"#{month}\"]")
    expect(rendered).to have_css(".memorable-date__day[value=\"#{day}\"]")
    expect(rendered).to have_css(".memorable-date__year[value=\"#{year}\"]")
  end

  it 'does not set the date fields to required by default' do
    expect(rendered).not_to have_css('.memorable-date__month[required="required"]')
    expect(rendered).not_to have_css('.memorable-date__day[required="required"]')
    expect(rendered).not_to have_css('.memorable-date__year[required="required"]')
  end

  context 'date fields lack values' do
    let(:month) { nil }
    let(:day) { nil }
    let(:year) { nil }

    it 'displays the date fields with empty values' do
      expect(rendered).to have_css('.memorable-date__month:not([value])')
      expect(rendered).to have_css('.memorable-date__day:not([value])')
      expect(rendered).to have_css('.memorable-date__year:not([value])')
    end
  end

  context 'required flag is set' do
    let(:required) { true }
    it 'sets the date fields to required' do
      expect(rendered).to have_css('.memorable-date__month[required="required"]')
      expect(rendered).to have_css('.memorable-date__day[required="required"]')
      expect(rendered).to have_css('.memorable-date__year[required="required"]')
    end
  end

  it 'uses default error messages' do
    formatted_min = I18n.l(Date.parse(min), format: t('date.formats.long'))
    formatted_max = I18n.l(Date.parse(max), format: t('date.formats.long'))
    # p rendered.css('.memorable-date__error-strings')[0].inner_text
    expect(
      JSON.parse(rendered.css('.memorable-date__error-strings')[0].inner_text),
    ).to eq(
      {
        'error_messages' => {
          'missing_month_day_year' => t(
            'components.memorable_date.errors.missing_month_day_year',
            label: label,
          ),
          'missing_month_day' => t('components.memorable_date.errors.missing_month_day'),
          'missing_month_year' => t('components.memorable_date.errors.missing_month_year'),
          'missing_day_year' => t('components.memorable_date.errors.missing_day_year'),
          'missing_month' => t('components.memorable_date.errors.missing_month'),
          'missing_day' => t('components.memorable_date.errors.missing_day'),
          'missing_year' => t('components.memorable_date.errors.missing_year'),
          'invalid_month' => t('components.memorable_date.errors.invalid_month'),
          'invalid_day' => t('components.memorable_date.errors.invalid_day'),
          'invalid_year' => t('components.memorable_date.errors.invalid_year'),
          'invalid_date' => t('components.memorable_date.errors.invalid_date'),
          'range_underflow' =>
            t(
              'components.memorable_date.errors.range_underflow', label: label,
                                                                  date: formatted_min
            ),
          'range_overflow' =>
          t(
            'components.memorable_date.errors.range_overflow', label: label,
                                                               date: formatted_max
          ),
          'outside_date_range' =>
          t(
            'components.memorable_date.errors.outside_date_range',
            label: label,
            min: formatted_min,
            max: formatted_max,
          ),
        },
        'range_errors' => [],
      },
    )
  end

  context 'alternate error messages are provided' do
    let(:error_messages) do
      {
        missing_month_day_year: 'a',
        missing_month_day: 'b',
        missing_month_year: 'c',
        missing_day_year: 'd',
        missing_month: 'e',
        missing_day: 'f',
        missing_year: 'g',
        invalid_month: 'h',
        invalid_day: 'i',
        invalid_year: 'j',
        invalid_date: 'k',
        range_underflow: 'l',
        range_overflow: 'm',
        outside_date_range: 'n',
      }
    end
    let(:range_errors) do
      [
        {
          min: Date.parse('1918-12-31'),
          max: Date.parse('2300-09-28'),
          message: 'oops',
        },
      ]
    end

    it 'uses the alternate error messages' do
      expect(
        JSON.parse(rendered.css('.memorable-date__error-strings')[0].inner_text),
      ).to eq(
        {
          'error_messages' => error_messages.stringify_keys,
          'range_errors' => [{
            'min' => '1918-12-31',
            'max' => '2300-09-28',
            'message' => 'oops',
          }],
        },
      )
    end
  end

  it 'renders aria-describedby to establish connection between input and error message' do
    field = rendered.at_css('input')

    expect(field.attr('aria-describedby')).to start_with('validated-field-error-')
  end

  it 'renders a non-visible error message element' do
    expect(rendered).to_not have_css('.usa-error-message', visible: true)
    expect(rendered).to have_css('.usa-error-message', visible: false)
  end

  context 'tag options are specified' do
    let(:tag_options) do
      {
        id: 'tag-options-test',
      }
    end

    it 'renders with the tag options' do
      expect(rendered).to have_css('lg-memorable-date#tag-options-test')
    end
  end

  it 'provides a method for parsing the submitted date' do
    expect(
      MemorableDateComponent.extract_date_param(
        day: '14',
        month: '2',
        year: '1990',
      ),
    ).to eq('1990-02-14')
    expect(
      MemorableDateComponent.extract_date_param(
        day: '14',
        month: '2',
        year: '90',
      ),
    ).to be_nil
    expect(
      MemorableDateComponent.extract_date_param(
        month: '2',
        year: '1990',
      ),
    ).to be_nil
    expect(
      MemorableDateComponent.extract_date_param(
        day: '14',
        year: '1990',
      ),
    ).to be_nil
    expect(
      MemorableDateComponent.extract_date_param(
        month: '2',
        year: '1990',
      ),
    ).to be_nil
    expect(
      MemorableDateComponent.extract_date_param(
        day: '14',
        month: '2',
        year: '19a0',
      ),
    ).to be_nil
    expect(
      MemorableDateComponent.extract_date_param('abcd'),
    ).to be_nil
  end
end
