require 'rails_helper'

RSpec.describe ClipboardButtonComponent, type: :component do
  let(:clipboard_text) { 'Copy Text' }
  let(:button_options) { {} }

  subject(:rendered) do
    render_inline ClipboardButtonComponent.new(clipboard_text:, **button_options)
  end

  it 'renders with clipboard text as attribute' do
    expect(rendered).to have_css("lg-clipboard-button[clipboard-text='#{clipboard_text}']")
  end

  it 'renders success label for copied state' do
    expect(rendered).to have_css(
      "lg-clipboard-button[tooltip-text='#{t('components.clipboard_button.tooltip')}']",
    )
  end

  it 'renders a copy button' do
    expect(rendered).to have_button(t('components.clipboard_button.label'), type: 'button')
  end

  context 'with tag options' do
    let(:button_options) { { variant: :quaternary, size: :sm, data: { foo: 'bar' } } }

    it 'passes options through to the button' do
      expect(rendered).to have_css('button[data-foo="bar"]')
    end
  end
end
