require 'rails_helper'

RSpec.describe IconComponent, type: :component do
  let(:asset_host) { 'http://wrong.example.com' }
  let(:domain_name) { 'http://correct.example.com' }

  before do
    allow(IdentityConfig.store).to receive(:asset_host).and_return(asset_host)
    allow(IdentityConfig.store).to receive(:domain_name).and_return(domain_name)
  end

  it 'renders icon svg' do
    rendered = render_inline IconComponent.new(icon: :print)

    expect(rendered).to have_css(".usa-icon use[href^='#{request.base_url}'][href$='.svg#print']")
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

  context 'in production' do
    before do
      allow(Rails.env).to receive(:production?).and_return(true)
    end

    it 'bypasses configured asset_host and uses domain_name instead' do
      rendered = render_inline IconComponent.new(icon: :print)

      href = rendered.css('use').first['href']

      expect(href).to start_with(domain_name)
    end
  end
end
