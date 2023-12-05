require 'rails_helper'

RSpec.describe ProcessListComponent, type: :component do
  it 'renders with css class' do
    rendered = render_inline ProcessListComponent.new

    expect(rendered).to have_css('.usa-process-list')
  end

  it 'renders items slot content at default heading level' do
    rendered = render_inline ProcessListComponent.new do |c|
      c.with_item(heading: 'Item 1') { 'Item 1 Content' }
      c.with_item(heading: 'Item 2') { 'Item 2 Content' }
    end

    expect(rendered).to have_css('h2.usa-process-list__heading', text: 'Item 1')
    expect(rendered).to have_css('.usa-process-list__item', text: 'Item 1 Content')
    expect(rendered).to have_css('h2.usa-process-list__heading', text: 'Item 2')
    expect(rendered).to have_css('.usa-process-list__item', text: 'Item 2 Content')
  end

  context 'custom heading level' do
    it 'renders items slot content at custom heading level' do
      rendered = render_inline ProcessListComponent.new(heading_level: :h3) do |c|
        c.with_item(heading: 'Item') { '' }
      end

      expect(rendered).to have_css('h3.usa-process-list__heading', text: 'Item')
    end
  end

  context 'big' do
    it 'renders with css class' do
      rendered = render_inline ProcessListComponent.new(big: true)

      expect(rendered).to have_css('.usa-process-list--big')
    end
  end

  context 'connected' do
    it 'renders with css class' do
      rendered = render_inline ProcessListComponent.new(connected: true)

      expect(rendered).to have_css('.usa-process-list--connected')
    end
  end

  context 'custom class' do
    it 'renders with css class' do
      rendered = render_inline ProcessListComponent.new(class: 'my-custom-class')

      expect(rendered).to have_css('.usa-process-list.my-custom-class')
    end
  end

  context 'with specified id' do
    it 'renders with css class' do
      rendered = render_inline ProcessListComponent.new(id: 'my-custom-id')

      expect(rendered).to have_selector('#my-custom-id')
    end
  end

  context 'tag options' do
    it 'applies tag options to wrapper element' do
      rendered = render_inline ProcessListComponent.new(data: { foo: 'bar' })

      expect(rendered).to have_css('.usa-process-list[data-foo="bar"]')
    end
  end
end
