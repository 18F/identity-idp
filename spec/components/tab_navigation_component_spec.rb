require 'rails_helper'

RSpec.describe TabNavigationComponent, type: :component do
  let(:label) { 'Navigation' }
  let(:routes) { [{ path: '/first', text: 'First' }, { path: '/second', text: 'Second' }] }
  let(:tag_options) { { label:, routes: } }

  subject(:rendered) do
    render_inline TabNavigationComponent.new(**tag_options)
  end

  it 'renders labelled navigation' do
    expect(rendered).to have_css('.tab-navigation[aria-label="Navigation"]')
    expect(rendered).to have_link('First') { |link| !is_current_link?(link) }
    expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
  end

  context 'with tag options' do
    let(:tag_options) { super().merge(data: { foo: 'bar' }, class: 'example') }

    it 'renders with tag options forwarded to navigation' do
      expect(rendered).to have_css('.tab-navigation.example[data-foo="bar"]')
    end
  end

  context 'with link for current request' do
    before do
      allow(vc_test_request).to receive(:path).and_return('/first')
    end

    it 'renders current link as highlighted' do
      expect(rendered).to have_link('First') { |link| is_current_link?(link) }
      expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
    end

    context 'with routes defining full URL' do
      let(:routes) do
        [
          { path: 'https://example.com/first', text: 'First' },
          { path: 'https://example.com/second', text: 'Second' },
        ]
      end

      it 'renders current link as highlighted' do
        expect(rendered).to have_link('First') { |link| is_current_link?(link) }
        expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
      end
    end

    context 'with routes including query parameters' do
      let(:routes) do
        [
          { path: '/first?foo=bar', text: 'First' },
          { path: '/second?foo=bar', text: 'Second' },
        ]
      end

      it 'renders current link as highlighted' do
        expect(rendered).to have_link('First') { |link| is_current_link?(link) }
        expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
      end
    end

    context 'unparseable route' do
      let(:routes) do
        [
          { path: '😬', text: 'First' },
          { path: '😬', text: 'Second' },
        ]
      end

      it 'renders gracefully without highlighted link' do
        expect(rendered).to have_link('First') { |link| !is_current_link?(link) }
        expect(rendered).to have_link('Second') { |link| !is_current_link?(link) }
      end
    end
  end

  def is_current_link?(link)
    link.matches_css?('[aria-current="page"]:not(.usa-button--outline)')
  end
end
