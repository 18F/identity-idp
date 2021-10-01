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
end
