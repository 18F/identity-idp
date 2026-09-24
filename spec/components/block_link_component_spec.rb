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

  context 'with an unsafe url scheme' do
    it 'raises for a javascript: url' do
      expect { BlockLinkComponent.new(url: 'javascript:alert(1)') }
        .to raise_error(ArgumentError, /^Unsafe URL scheme/)
    end

    it 'raises for a data: url' do
      expect { BlockLinkComponent.new(url: 'data:text/html,<script>alert(1)</script>') }
        .to raise_error(ArgumentError, /^Invalid URL/)
    end

    it 'raises for a vbscript: url' do
      expect { BlockLinkComponent.new(url: 'vbscript:msgbox(1)') }
        .to raise_error(ArgumentError, /^Unsafe URL scheme/)
    end

    it 'raises for a mixed-case scheme' do
      expect { BlockLinkComponent.new(url: 'JavaScript:alert(1)') }
        .to raise_error(ArgumentError, /^Unsafe URL scheme/)
    end

    it 'raises when the scheme is obscured by leading whitespace' do
      expect { BlockLinkComponent.new(url: ' javascript:alert(1)') }
        .to raise_error(ArgumentError, /^Unsafe URL scheme/)
    end
  end

  context 'with a safe url' do
    ['/', '#', 'https://example.com', '/path?query=1', 'relative/path'].each do |url|
      it "renders a link for #{url.inspect}" do
        rendered = render_inline BlockLinkComponent.new(url:).with_content('Link Text')

        expect(rendered).to have_link('Link Text', href: url)
      end
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
