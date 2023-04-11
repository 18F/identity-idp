require 'rails_helper'

RSpec.describe TabNavigationComponent, type: :component do
  let(:label) { 'Navigation' }
  let(:routes) { [{ path: '/first', text: 'First' }, { path: '/second', text: 'Second' }] }
  let(:tag_options) { { label:, routes: } }

  subject(:rendered) do
    render_inline TabNavigationComponent.new(**tag_options)
  end

  it 'renders labelled navigation' do
    expect(rendered).to have_css('nav[aria-label="Navigation"]')
    expect(rendered).to have_link('First') { |link| !is_current_link?(link) }
    expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
  end

  context 'with tag options' do
    let(:tag_options) { super().merge(data: { foo: 'bar' }) }

    it 'renders with tag options forwarded to navigation' do
      expect(rendered).to have_css('nav[data-foo="bar"]')
    end
  end

  context 'with link for current request' do
    before do
      allow(request).to receive(:path).and_return('/first')
    end

    it 'renders current link as highlighted' do
      expect(rendered).to have_link('First') { |link| is_current_link?(link) }
      expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
    end
  end

  def is_current_link?(link)
    link.matches_css?('[aria-current="page"]:not(.usa-button--outline)')
  end
end
