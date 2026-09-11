require 'rails_helper'

RSpec.describe NDS::LinkComponent, type: :component do
  it 'renders an anchor with the .link class to the url' do
    rendered = render_inline(NDS::LinkComponent.new(url: '/somewhere')) { 'Go' }
    expect(rendered).to have_css('a.link[href="/somewhere"]', text: 'Go')
  end

  it 'merges custom classes with .link' do
    rendered = render_inline(NDS::LinkComponent.new(url: '/x', class: 'link--nowrap')) { 'Go' }
    expect(rendered).to have_css('a.link.link--nowrap')
  end

  it 'passes through extra html options' do
    rendered = render_inline(
      NDS::LinkComponent.new(url: '/x', target: '_blank'),
    ) { 'Go' }
    expect(rendered).to have_css('a.link[target="_blank"]')
  end
end
