require 'rails_helper'

RSpec.describe NDS::StackComponent, type: :component do
  it 'renders a div.stack by default' do
    rendered = render_inline(NDS::StackComponent.new) { 'x' }
    expect(rendered).to have_css('div.stack', text: 'x')
  end

  it 'maps kind to the base class' do
    {
      stack: 'stack', flow: 'flow', form: 'form', actions: 'actions', links: 'links'
    }.each do |kind, base|
      rendered = render_inline(NDS::StackComponent.new(kind:)) { 'x' }
      expect(rendered).to have_css("div.#{base}")
    end
  end

  it 'adds a gap modifier scoped to the base class' do
    rendered = render_inline(NDS::StackComponent.new(kind: :form, gap: 32)) { 'x' }
    expect(rendered).to have_css('div.form.form--gap-32')
  end

  it 'adds an align modifier scoped to the base class' do
    rendered = render_inline(NDS::StackComponent.new(kind: :actions, align: :center)) { 'x' }
    expect(rendered).to have_css('div.actions.actions--align-center')
  end

  it 'dasherizes align values' do
    rendered = render_inline(NDS::StackComponent.new(align: :mobile_start)) { 'x' }
    expect(rendered).to have_css('div.stack.stack--align-mobile-start')
  end

  it 'ignores a non-integer gap' do
    rendered = render_inline(NDS::StackComponent.new(gap: 'bogus')) { 'x' }
    expect(rendered).to have_css('div.stack')
    expect(rendered).not_to have_css('[class*="--gap-"]')
  end

  it 'honors a custom tag and passes through extra html options' do
    rendered = render_inline(
      NDS::StackComponent.new(tag: :ul, kind: :links, class: 'extra', data: { foo: 'bar' }),
    ) { 'x' }
    expect(rendered).to have_css('ul.links.extra[data-foo="bar"]')
  end
end
