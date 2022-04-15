require 'rails_helper'

RSpec.describe PrintButtonComponent, type: :component do
  let(:tag_options) { {} }

  subject(:rendered) do
    render_inline PrintButtonComponent.new(**tag_options)
  end

  it 'renders custom element with button' do
    expect(rendered).to have_css(
      'lg-print-button button[type="button"]',
      text: t('components.print_button.label'),
    )
  end

  context 'with tag options' do
    let(:tag_options) { { outline: true, data: { foo: 'bar' } } }

    it 'renders with tag options forwarded to button' do
      expect(rendered).to have_css(
        'lg-print-button button.usa-button--outline:not([outline])[data-foo="bar"]',
      )
    end
  end
end
