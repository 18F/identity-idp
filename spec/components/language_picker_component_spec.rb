require 'rails_helper'

RSpec.describe LanguagePickerComponent, type: :component do
  around do |example|
    with_request_url('/') { example.run }
  end

  it 'renders collapsed language picker accordion element' do
    rendered = render_inline LanguagePickerComponent.new

    expect(rendered).to have_css('.language-picker.usa-accordion')
    expect(rendered).to have_css('.usa-accordion__button[aria-expanded="false"]')
    expect(rendered).to have_css('.usa-accordion__content', visible: false)
  end

  context 'with tag options' do
    it 'renders with attributes' do
      rendered = render_inline LanguagePickerComponent.new(class: 'example', data: { foo: 'bar' })

      expect(rendered).to have_css('.language-picker.usa-accordion.example[data-foo="bar"]')
    end
  end

  context 'with custom url generator' do
    it 'uses url generator to generate locale links' do
      rendered = render_inline LanguagePickerComponent.new(
        url_generator: ->(params) { "/#{params[:locale]}" },
      )

      actual_hrefs = rendered.css('a').pluck(:href)
      expected_hrefs = I18n.available_locales.map { |locale| "/#{locale}" }

      expect(actual_hrefs).to match_array(expected_hrefs)
    end
  end
end
