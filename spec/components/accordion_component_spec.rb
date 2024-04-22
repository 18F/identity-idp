require 'rails_helper'

RSpec.describe AccordionComponent, type: :component do
  let(:bordered) { nil }
  let(:tag_options) { {} }
  let(:options) { { bordered:, **tag_options }.compact }

  subject(:rendered) do
    render_inline(described_class.new(**options)) do |c|
      c.with_header { 'heading' }
      'content'
    end
  end

  it 'renders an accordion' do
    expect(rendered).to have_css('.usa-accordion.usa-accordion--bordered')
    expect(rendered).to have_css('.usa-accordion__heading', text: 'heading')
    expect(rendered).to have_css('.usa-accordion__content', text: 'content')
  end

  it 'assigns a unique id' do
    second_rendered = render_inline(described_class.new)

    rendered_id = rendered.css('.usa-accordion__content').first['id']
    second_rendered_id = second_rendered.css('.usa-accordion__content').first['id']

    expect(rendered_id).to be_present
    expect(second_rendered_id).to be_present
    expect(rendered_id).to_not eq(second_rendered_id)
  end

  context 'borderless' do
    let(:bordered) { false }

    it 'renders without bordered modifier' do
      expect(rendered).to have_css('.usa-accordion:not(.usa-accordion--bordered)')
    end
  end

  context 'custom class' do
    let(:tag_options) { { class: 'example-class' } }

    it 'merges with base classes' do
      expect(rendered).to have_css('.usa-accordion.usa-accordion--bordered.example-class')
    end
  end

  context 'tag options' do
    let(:tag_options) { { data: { foo: 'bar' } } }

    it 'renders with tag options' do
      expect(rendered).to have_css('.usa-accordion[data-foo="bar"]')
    end
  end
end
