require 'rails_helper'

RSpec.describe 'shared/_masked_text.html.erb' do
  let(:text) { 'password' }
  let(:masked_text) { '********' }
  let(:accessible_masked_text) { 'secure text' }
  let(:id) { nil }
  let(:toggle_label) { nil }

  before do
    local_assigns = {
      text: text,
      masked_text: masked_text,
      accessible_masked_text: accessible_masked_text,
    }
    local_assigns[:id] = id if id
    local_assigns[:toggle_label] = toggle_label if toggle_label

    render('shared/masked_text', local_assigns)
  end

  it 'renders texts' do
    expect(rendered).to have_css('.ads-masked-text__text[hidden]', text: text, visible: :hidden)
    expect(rendered).to have_css(
      '.ads-masked-text__value[aria-hidden]',
      text: masked_text.tr('*', '•'),
    )
    expect(rendered).to have_css('.ads-sr-only', text: accessible_masked_text)
  end

  context 'without toggle' do
    let(:toggle_label) { nil }

    it 'does not render with toggle' do
      expect(rendered).not_to have_css('input')
    end
  end

  context 'with toggle' do
    let(:toggle_label) { 'Show password' }

    it 'renders with icon toggle' do
      expect(rendered).to have_css('input.ads-masked-text__toggle[aria-controls]', visible: :hidden)
      expect(rendered).to have_css('label.ads-masked-text__icon-toggle', text: toggle_label)
    end

    context 'with custom id' do
      let(:id) { 'custom-id' }

      it 'renders with custom id' do
        expect(rendered).to have_css(
          'input#custom-id-checkbox[aria-controls="custom-id"]',
          visible: :hidden,
        )
      end
    end
  end
end
