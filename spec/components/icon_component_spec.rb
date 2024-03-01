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

    icon = rendered.at_css('.icon.usa-icon')
    id = icon.attr(:id)
    inline_style = rendered.at_css('style').text.strip

    expect(icon).to be_present
    expect(inline_style).to match(%r{##{id}\s{.+?}}).
      and(include('-webkit-mask-image:')).
      and(include('mask-image:')).
      and(match(%r{url\([^)]+/print-\w+\.svg\)}))
  end

  context 'with invalid icon' do
    it 'raises an error' do
      expect { render_inline IconComponent.new(icon: :foo) }.to raise_error(ArgumentError)
    end
  end

  context 'with size' do
    it 'adds size variant class' do
      rendered = render_inline IconComponent.new(icon: :print, size: 2)

      expect(rendered).to have_css('.icon.usa-icon.usa-icon--size-2')
    end
  end

  context 'with custom class' do
    it 'renders with class' do
      rendered = render_inline IconComponent.new(icon: :print, class: 'my-custom-class')

      expect(rendered).to have_css('.icon.usa-icon.my-custom-class')
    end
  end

  context 'with tag options' do
    it 'renders with attributes' do
      rendered = render_inline IconComponent.new(icon: :print, data: { foo: 'bar' })

      expect(rendered).to have_css('.icon.usa-icon[data-foo="bar"]')
    end
  end

  context 'in production' do
    before do
      allow(Rails.env).to receive(:production?).and_return(true)
    end

    it 'bypasses configured asset_host and uses domain_name instead' do
      rendered = render_inline IconComponent.new(icon: :print)

      inline_style = rendered.at_css('style').text.strip

      expect(inline_style).to match(%r{url\(#{Regexp.escape(domain_name)}})
    end
  end
end
