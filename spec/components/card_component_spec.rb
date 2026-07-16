require 'rails_helper'

RSpec.describe CardComponent, type: :component do
  subject(:rendered) { render_inline(component) { content } }

  let(:options) { {} }
  let(:content) { 'Card body' }
  let(:component) { CardComponent.new(**options) }

  context 'with url' do
    let(:options) { { url: '/example' } }

    it 'acts as a link' do
      expect(rendered).to have_link('Card body', href: '/example')
    end
  end

  context 'with button' do
    let(:options) { { button: true } }

    it 'acts as a button' do
      expect(rendered).to have_button('Card body')
    end
  end

  context 'with non-get method' do
    let(:options) { { url: '/example', method: :post } }

    it 'submits the configured method' do
      expect(rendered).to have_selector("form[action='/example'][method='post']")
      expect(rendered).to have_button('Card body')
    end
  end

  it 'rejects simultaneous URL and button modes' do
    expect do
      render_inline(described_class.new(url: '/example', button: true)) { content }
    end.to raise_error(ActiveModel::ValidationError, /Button/)
  end
end
