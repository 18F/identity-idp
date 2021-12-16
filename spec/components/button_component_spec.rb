require 'rails_helper'

RSpec.describe ButtonComponent, type: :component do
  let(:type) { nil }
  let(:outline) { false }
  let(:content) { 'Button' }
  let(:options) do
    {
      outline: outline,
      type: type,
    }.compact
  end

  subject(:rendered) { render_inline ButtonComponent.new(options) { content } }

  it 'renders button content' do
    expect(rendered).to have_content(content)
  end

  it 'renders as type=button' do
    expect(rendered).to have_css('button[type=button]')
  end

  it 'renders with design system classes' do
    expect(rendered).to have_css('button.usa-button')
  end

  context 'with outline' do
    let(:outline) { true }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.usa-button--outline')
    end
  end

  context 'with type' do
    let(:type) { :submit }

    it 'renders as type' do
      expect(rendered).to have_css('button[type=submit]')
    end
  end
end
