require 'rails_helper'

RSpec.describe TroubleshootingOptionsComponent, type: :component do
  it 'renders nothing if not given options' do
    rendered = render_inline TroubleshootingOptionsComponent.new

    expect(rendered.children).to be_empty
  end

  context 'with options' do
    it 'renders troubleshooting options' do
      rendered = render_inline(TroubleshootingOptionsComponent.new) do |c|
        c.option(url: '/').with_content('Link Text')
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
        ) { |c| c.option(url: '/').with_content('Link Text') }

        expect(rendered).to have_css('.troubleshooting-options.my-custom-class[data-foo="bar"]')
      end
    end

    context 'with :new_features' do
      it 'renders a new features tag' do
        rendered = render_inline(
          TroubleshootingOptionsComponent.new(new_features: true),
        ) { |c| c.option(url: '/').with_content('Link Text') }

        expect(rendered).to have_css(
          '.troubleshooting-options .usa-tag.text-uppercase',
          text: t('components.troubleshooting_options.new_feature'),
        )
      end
    end

    context 'with header' do
      it 'renders header' do
        rendered = render_inline(TroubleshootingOptionsComponent.new) do |c|
          c.header { 'Heading' }
          c.option(url: '/')
        end

        expect(rendered).to have_css('h2.troubleshooting-options__heading', text: 'Heading')
      end

      context 'with custom heading level' do
        it 'renders header' do
          rendered = render_inline(TroubleshootingOptionsComponent.new) do |c|
            c.header(heading_level: :h3) { 'Heading' }
            c.option(url: '/')
          end

          expect(rendered).to have_css('h3.troubleshooting-options__heading', text: 'Heading')
        end
      end
    end
  end
end
