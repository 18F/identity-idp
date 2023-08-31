require 'rails_helper'

RSpec.describe PageFooterComponent, type: :component do
  it 'renders content' do
    content = 'Footer'
    rendered = render_inline PageFooterComponent.new.with_content(content)

    expect(rendered).to have_content(content)
    expect(rendered).to have_css('.page-footer')
  end

  context 'tag options' do
    it 'appends attributes' do
      rendered = render_inline PageFooterComponent.new(data: { foo: 'bar' })

      expect(rendered).to have_css('[data-foo="bar"]')
    end
  end

  context 'custom class' do
    it 'appends custom class' do
      rendered = render_inline PageFooterComponent.new(class: 'custom-class')

      expect(rendered).to have_css('.page-footer.custom-class')
    end
  end
end
