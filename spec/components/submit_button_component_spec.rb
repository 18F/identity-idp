require 'rails_helper'

RSpec.describe SubmitButtonComponent, type: :component do
  let(:options) { {} }
  let(:content) { 'Button' }

  subject(:rendered) do
    render_inline described_class.new(**options).with_content(content)
  end

  it 'renders the submit button custom element' do
    expect(rendered).to have_css('lg-submit-button')
    expect(rendered).to have_css('button.usa-button')
    expect(rendered).to have_content(content)
  end

  it 'renders as big, wide by default' do
    expect(rendered).to have_css('.usa-button.usa-button--big.usa-button--wide')
  end

  context 'with explicit big, wide options' do
    let(:options) { { big: false, wide: false } }

    it 'renders respecting big, wide options' do
      expect(rendered).to have_css('.usa-button:not(.usa-button--big):not(.usa-button--wide)')
    end
  end

  context 'with additional options' do
    let(:options) { { unstyled: true, data: { foo: 'bar' } } }

    it 'passes additional options through to ButtonComponent' do
      expect(rendered).to have_css('.usa-button.usa-button--unstyled[data-foo="bar"]')
    end
  end
end
