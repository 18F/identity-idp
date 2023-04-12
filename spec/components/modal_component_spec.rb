require 'rails_helper'

RSpec.describe ModalComponent, type: :component do
  include ActionView::Helpers::TagHelper

  it 'renders modal element' do
    rendered = render_inline ModalComponent.new

    expect(rendered).to have_css('lg-modal', visible: false)
  end

  it 'renders label and description association' do
    rendered = render_inline ModalComponent.new do |c|
      safe_join [
        content_tag(:h1, 'Heading', id: c.label_id),
        content_tag(:p, 'Description', id: c.description_id),
      ]
    end

    dialog = rendered.css('[role="dialog"]').first
    labelledby_id = dialog['aria-labelledby']
    describedby_id = dialog['aria-describedby']
    heading_id = rendered.css('h1').first['id']
    description_id = rendered.css('p').first['id']

    expect(labelledby_id).to eq(heading_id)
    expect(describedby_id).to eq(description_id)
  end

  it 'renders with dismiss button' do
    rendered = render_inline ModalComponent.new do |c|
      c.dismiss_button(outline: true) { 'Dismiss' }
    end

    expect(rendered).to have_css(
      '.usa-button--outline[data-dismiss]',
      text: 'Dismiss',
      visible: false,
    )
  end

  context 'with tag options' do
    it 'renders modal with the tag options' do
      rendered = render_inline ModalComponent.new(class: 'example', data: { foo: 'bar' })

      expect(rendered).to have_css('lg-modal.example[data-foo="bar"]', visible: false)
    end
  end
end
