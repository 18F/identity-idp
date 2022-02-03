require 'rails_helper'

RSpec.describe ButtonComponent, type: :component do
  let(:type) { nil }
  let(:outline) { false }
  let(:content) { 'Button' }
  let(:options) do
    {
      type: type,
    }.compact
  end

  subject(:rendered) do
    render_inline ButtonComponent.new(outline: outline, **options).with_content(content)
  end

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

  context 'with icon' do
    it 'renders an icon' do
      rendered = render_inline ButtonComponent.new(icon: :print).with_content(content)

      expect(rendered).to have_css('use[href$="#print"]')
      expect(rendered.first_element_child.xpath('./text()').text).to eq(content)
    end
  end

  context 'with custom button tag factory' do
    it 'sends to factory method' do
      rendered = render_inline ButtonComponent.new('/', factory: :button_to) { content }

      expect(rendered).to have_css('form[action="/"]')
    end
  end
end
