require 'rails_helper'

RSpec.describe AccordionComponent, type: :component do
  subject(:rendered) do
    render_inline(described_class.new) do |c|
      c.header { 'heading' }
      'content'
    end
  end

  it 'renders an accordion' do
    expect(rendered).to have_css('.usa-accordion__heading', text: 'heading')
    expect(rendered).to have_css('.usa-accordion__content', text: 'content')
  end

  it 'assigns a unique id' do
    second_rendered = render_inline(described_class.new)

    rendered_id = rendered.css('.usa-accordion__container').first['id']
    second_rendered_id = second_rendered.css('.usa-accordion__container').first['id']

    expect(rendered_id).to be_present
    expect(second_rendered_id).to be_present
    expect(rendered_id).to_not eq(second_rendered_id)
  end
end
