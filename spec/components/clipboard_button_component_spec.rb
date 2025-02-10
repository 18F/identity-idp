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

  it 'renders with tootip text as attribute' do
    expect(rendered).to have_css(
      "lg-clipboard-button[tooltip-text='#{t('components.clipboard_button.tooltip')}']",
    )
  end

  context 'with tag options' do
    let(:button_options) { { outline: true, data: { foo: 'bar' } } }

    it 'renders button given the tag options' do
      expect(rendered).to have_css('button.usa-button[type="button"][data-foo="bar"]')
    end

    it 'respects keyword arguments of button component' do
      expect(rendered).to have_css('.usa-button--outline:not([outline])')
    end
  end

  context 'with unstyled button' do
    let(:button_options) { { unstyled: true } }

    it 'renders with modifier class' do
      expect(rendered).to have_css('lg-clipboard-button.clipboard-button--unstyled')
    end
  end
end
