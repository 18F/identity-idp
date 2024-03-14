require 'rails_helper'

RSpec.describe TagComponent, type: :component do
  let(:content) { 'Example' }

  it 'renders a tag with default attributes' do
    rendered = render_inline TagComponent.new.with_content(content)

    expect(rendered).to have_css('.usa-tag', text: content)
  end

  context 'with big size' do
    it 'renders with variant class' do
      rendered = render_inline TagComponent.new(big: true).with_content(content)

      expect(rendered).to have_css('.usa-tag.usa-tag--big')
    end
  end

  context 'with informative style' do
    it 'renders with variant class' do
      rendered = render_inline TagComponent.new(informative: true).with_content(content)

      expect(rendered).to have_css('.usa-tag.usa-tag--informative')
    end
  end

  context 'with custom class' do
    it 'renders with custom class' do
      rendered = render_inline TagComponent.new(class: 'my-custom-class').with_content(content)

      expect(rendered).to have_css('.usa-tag.my-custom-class')
    end
  end

  context 'with tag options' do
    it 'renders with attributes' do
      rendered = render_inline TagComponent.new(data: { foo: 'bar' })

      expect(rendered).to have_css('.usa-tag[data-foo="bar"]')
    end
  end
end
