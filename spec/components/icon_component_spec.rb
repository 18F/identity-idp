require 'rails_helper'

RSpec.describe IconComponent, type: :component do
  it 'renders icon svg' do
    rendered = render_inline IconComponent.new(icon: :print)

    expect(rendered).to have_css('.usa-icon use[href$=".svg#print"]')
  end

  context 'with invalid icon' do
    it 'raises an error' do
      expect { render_inline IconComponent.new(icon: :foo) }.to raise_error(ArgumentError)
    end
  end

  context 'with custom class' do
    it 'renders with class' do
      rendered = render_inline IconComponent.new(icon: :print, class: 'my-custom-class')

      expect(rendered).to have_css('.usa-icon.my-custom-class')
    end
  end

  context 'with tag options' do
    it 'renders with attributes' do
      rendered = render_inline IconComponent.new(icon: :print, data: { foo: 'bar' })

      expect(rendered).to have_css('.usa-icon[data-foo="bar"]')
    end
  end
end
