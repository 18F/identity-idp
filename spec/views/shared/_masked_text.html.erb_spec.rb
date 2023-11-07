require 'rails_helper'

RSpec.describe 'shared/_masked_text.html.erb' do
  let(:text) { 'password' }
  let(:masked_text) { '********' }
  let(:accessible_masked_text) { 'secure text' }
  let(:id) { nil }
  let(:toggle_label) { nil }

  before do
    local_assigns = {
      text:,
      masked_text:,
      accessible_masked_text:,
    }
    local_assigns[:id] = id if id
    local_assigns[:toggle_label] = toggle_label if toggle_label

    render('shared/masked_text', local_assigns)
  end

  it 'renders texts' do
    expect(rendered).to have_css('.display-none', text:)
    expect(rendered).to have_css('[aria-hidden]', text: masked_text)
    expect(rendered).to have_css('.usa-sr-only', text: accessible_masked_text)
  end

  context 'without toggle' do
    let(:toggle_label) { nil }

    it 'does not render with toggle' do
      expect(rendered).not_to have_css('input')
    end
  end

  context 'with toggle' do
    let(:toggle_label) { 'Show password' }

    it 'renders with toggle' do
      expect(rendered).to have_css('input[aria-controls]')
    end

    context 'with custom id' do
      let(:id) { 'custom-id' }

      it 'renders with custom id' do
        expect(rendered).to have_css('input#custom-id-checkbox[aria-controls="custom-id"]')
      end
    end
  end
end
