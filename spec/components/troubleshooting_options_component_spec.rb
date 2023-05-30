require 'rails_helper'

RSpec.describe TroubleshootingOptionsComponent, type: :component do
  it 'renders nothing if not given options' do
    rendered = render_inline TroubleshootingOptionsComponent.new

    expect(rendered.children).to be_empty
  end

  context 'with options' do
    it 'renders troubleshooting options' do
      rendered = render_inline(TroubleshootingOptionsComponent.new) do |c|
        c.with_option(url: '/').with_content('Link Text')
      end

      expect(rendered).to have_css('.troubleshooting-options')
      expect(rendered).to have_link('Link Text', href: '/')
    end

    context 'with tag options' do
      it 'renders troubleshooting options' do
        rendered = render_inline(
          TroubleshootingOptionsComponent.new(
            class: 'my-custom-class',
            data: { foo: 'bar' },
          ),
        ) { |c| c.with_option(url: '/').with_content('Link Text') }

        expect(rendered).to have_css('.troubleshooting-options.my-custom-class[data-foo="bar"]')
      end
    end

    context 'with header' do
      it 'renders header' do
        rendered = render_inline(TroubleshootingOptionsComponent.new) do |c|
          c.with_header { 'Heading' }
          c.with_option(url: '/')
        end

        expect(rendered).to have_css('h2.troubleshooting-options__heading', text: 'Heading')
      end

      context 'with custom heading level' do
        it 'renders header' do
          rendered = render_inline(TroubleshootingOptionsComponent.new) do |c|
            c.with_header(heading_level: :h3) { 'Heading' }
            c.with_option(url: '/')
          end

          expect(rendered).to have_css('h3.troubleshooting-options__heading', text: 'Heading')
        end
      end
    end
  end
end
