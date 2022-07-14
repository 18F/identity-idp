require 'rails_helper'

RSpec.describe BlockLinkComponent, type: :component do
  it 'renders a link' do
    rendered = render_inline BlockLinkComponent.new(url: '/').with_content('Link Text')

    expect(rendered).to have_link('Link Text', href: '/')
    expect(rendered).to have_css('.block-link.usa-link')
  end

  context 'with tag options' do
    it 'renders a link' do
      rendered = render_inline BlockLinkComponent.new(
        url: '/',
        class: 'my-custom-class',
        data: { foo: 'bar' },
      )

      expect(rendered).to have_css('.block-link.usa-link.my-custom-class[data-foo="bar"]')
    end
  end

  context 'with new tab' do
    it 'renders as external' do
      rendered = render_inline BlockLinkComponent.new(url: '/', new_tab: true)

      expect(rendered).to have_css('.block-link.usa-link.usa-link--external[target=_blank]')
      expect(rendered).to have_content(t('links.new_window'))
    end
  end

  context 'with custom renderer' do
    class ExampleBlockLinkCustomRendererComponent < BaseComponent
      def initialize(href:, **)
        @href = href
      end

      def call
        content_tag(:button, "Example #{content.strip}", data: { href: @href })
      end
    end

    it 'renders using the custom renderer' do
      rendered = render_inline BlockLinkComponent.new(
        url: '/',
        action: ExampleBlockLinkCustomRendererComponent.method(:new),
      ).with_content('Link Text')

      expect(rendered).to have_css('button[data-href="/"]', text: 'Example Link Text')
    end
  end
end
