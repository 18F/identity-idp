require 'rails_helper'

RSpec.describe ClickObserverComponent, type: :component do
  let(:event_name) { 'Event Name' }
  let(:content) { 'Content' }
  let(:tag_options) { {} }
  let(:payload) { { path: '/first' } }

  subject(:rendered) do
    render_inline ClickObserverComponent.new(
      event_name:,
      payload:,
      **tag_options,
    ).with_content(content)
  end

  it 'renders wrapped content with event name as attribute' do
    expect(rendered).to have_css("lg-click-observer[event-name='#{event_name}']", text: content)
  end

  context 'with payload attribute' do
    it 'renders with payload with json value' do
      expect(rendered).to have_css('lg-click-observer[payload="{\"path\":\"/first\"}"]')
    end
  end

  context 'with tag options' do
    let(:tag_options) { { data: { foo: 'bar' } } }

    it 'renders with the given the tag options' do
      expect(rendered).to have_css('lg-click-observer[data-foo="bar"]')
    end
  end
end
