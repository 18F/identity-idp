require 'rails_helper'

RSpec.describe SpinnerButtonComponent, type: :component do
  it 'renders a button with the given content and tag options' do
    render_inline SpinnerButtonComponent.new(
      outline: true,
      data: { foo: 'bar' },
    ).with_content('Click Me')

    button = page.find_button('Click Me', class: 'usa-button--outline')
    expect(button['data-foo']).to eq('bar')
  end

  it 'renders without action message' do
    rendered = render_inline SpinnerButtonComponent.new.with_content('')

    expect(rendered).to_not have_selector('.spinner-button__action-message')
  end

  context 'with action message' do
    it 'renders with action message' do
      rendered = render_inline SpinnerButtonComponent.new(
        action_message: 'Verifying...',
      ).with_content('')

      expect(rendered).to have_css('.spinner-button__action-message[data-message="Verifying..."]')
    end
  end

  context 'with outline button' do
    it 'renders with additional css class' do
      rendered = render_inline SpinnerButtonComponent.new(outline: true).with_content('')

      expect(rendered).to have_css('lg-spinner-button.spinner-button--outline')
    end
  end
end
