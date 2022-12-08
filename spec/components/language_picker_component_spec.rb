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

  it 'renders with accessible relationships' do
    rendered = render_inline LanguagePickerComponent.new

    list = rendered.at_css('ul')
    list_description = rendered.at_css("##{list['aria-describedby']}").text.strip
    button_controls = rendered.at_css("##{rendered.at_css('[aria-controls]')['aria-controls']}")

    expect(list_description).to eq(t('i18n.language'))
    expect(button_controls).to eq(list)
  end

  it 'renders language options in their native locale' do
    rendered = render_inline LanguagePickerComponent.new

    I18n.available_locales.each do |locale|
      expect(rendered).to have_xpath(
        ".//a[text()='#{t("i18n.locale.#{locale}", locale: locale)}'][@lang='#{locale}']",
        visible: false,
      )
    end
  end

  context 'with tag options' do
    it 'renders with attributes' do
      rendered = render_inline LanguagePickerComponent.new(class: 'example', data: { foo: 'bar' })

      expect(rendered).to have_css('.language-picker.usa-accordion.example[data-foo="bar"]')
    end
  end
end
