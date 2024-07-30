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
      expect(rendered).to have_content(t('links.new_tab'))
    end
  end

  context 'with a component' do
    before do
      stub_const(
        'TestComponent',
        Class.new(BaseComponent) do
          attr_reader :tag_options

          def initialize(**tag_options)
            @tag_options = tag_options
          end

          def call
            content_tag(:div, 'from test component', class: 'style')
          end
        end,
      )
    end

    it 'renders using the specified component' do
      rendered = render_inline(BlockLinkComponent.new(component: TestComponent))

      expect(rendered).to have_css('.style')
      expect(rendered).to have_text('from test component')
    end
  end
end
