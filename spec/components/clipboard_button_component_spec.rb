require 'rails_helper'

RSpec.describe ClipboardButtonComponent, type: :component do
  let(:clipboard_text) { 'Copy Text' }
  let(:content) { 'Button' }
  let(:tag_options) { {} }

  subject(:rendered) do
    render_inline ClipboardButtonComponent.new(clipboard_text: clipboard_text, **tag_options) do
      content
    end
  end

  it 'renders button content' do
    expect(rendered).to have_content(content)
  end

  it 'renders with clipboard text as data-attribute' do
    expect(rendered).to have_css("lg-clipboard-button[data-clipboard-text='#{clipboard_text}']")
  end

  context 'with tag options' do
    let(:tag_options) { { outline: true } }

    it 'renders button given the tag options' do
      expect(rendered).to have_css('button.usa-button.usa-button--outline')
    end
  end
end
