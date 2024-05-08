require 'rails_helper'

RSpec.describe BadgeComponent, type: :component do
  let(:icon) {}
  let(:content) { 'Content' }
  let(:options) { { icon: } }

  subject(:rendered) do
    render_inline BadgeComponent.new(**options).with_content(content)
  end

  context 'without icon' do
    let(:icon) { nil }

    it 'raises an exception' do
      expect { rendered }.to raise_error(ArgumentError)
    end
  end

  context 'with invalid icon' do
    let(:icon) { :invalid }

    it 'raises an exception' do
      expect { rendered }.to raise_error(ArgumentError)
    end
  end

  context 'with valid icon' do
    let(:icon) { :check_circle }

    it 'renders badge with icon and content' do
      expect(rendered).to have_css('.lg-verification-badge .usa-icon.text-success')
      inline_icon_style = rendered.at_css('.usa-icon style').text.strip
      expect(inline_icon_style).to match(%r{url\([^)]+?/check_circle-\w+\.svg\)})
    end

    context 'with extra tag options' do
      let(:options) { super().merge(class: 'example-class', data: { foo: 'bar' }) }

      it 'renders badge with extra tag options on wrapper element' do
        expect(rendered).to have_css('.lg-verification-badge.example-class[data-foo="bar"]')
      end
    end
  end
end
