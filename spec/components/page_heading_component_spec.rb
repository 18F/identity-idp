require 'rails_helper'

RSpec.describe PageHeadingComponent, type: :component do
  let(:tag_options) { {} }
  let(:content) { 'Heading' }

  subject(:rendered) { render_inline PageHeadingComponent.new(**tag_options).with_content(content) }

  it 'renders heading content' do
    expect(rendered).to have_content(content)
  end

  it 'renders class' do
    expect(rendered).to have_css('.page-heading')
  end

  context 'tag options' do
    let(:tag_options) { { data: { foo: 'bar' } } }

    it 'appends attributes' do
      expect(rendered).to have_css('.page-heading[data-foo="bar"]')
    end
  end

  context 'custom class' do
    let(:tag_options) { { class: 'custom-class' } }

    it 'appends custom class' do
      expect(rendered).to have_css('.page-heading.custom-class')
    end
  end
end
