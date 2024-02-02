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

  context 'when render_as_link is false' do
    it 'renders content within a div and not a link' do
      rendered = render_inline BlockLinkComponent.new(render_as_link: false, class: 'block-button').
        with_content('Not a link')

      expect(rendered).to have_css('div.block-button')
      expect(rendered).to have_text('Not a link')
      expect(rendered).to have_no_link
    end
  end
end
