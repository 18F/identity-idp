require 'rails_helper'

RSpec.describe SpinnerButtonComponent, type: :component do
  it 'renders a button with the given content and button options' do
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

  it 'renders without spin-on-click attribute by default' do
    render_inline SpinnerButtonComponent.new.with_content('hi')
    expect(page).to_not have_selector('[spin-on-click]')
  end

  it 'renders default long-duration-wait-ms attribute' do
    render_inline SpinnerButtonComponent.new.with_content('')

    element = page.find_css('lg-spinner-button').first

    expect(element['long-wait-duration-ms']).to eq(
      SpinnerButtonComponent::DEFAULT_LONG_WAIT_DURATION.in_milliseconds.to_s,
    )
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

  context 'with spin_on_click' do
    it 'renders spin-on-click attribute' do
      render_inline SpinnerButtonComponent.new(spin_on_click: true).with_content('')
      expect(page).to have_selector('[spin-on-click=true]')
    end
  end

  context 'with custom long wait duration' do
    it 'renders with customized long-duration-wait-ms attribute' do
      render_inline SpinnerButtonComponent.new(long_wait_duration: 1.second).with_content('')

      element = page.find_css('lg-spinner-button').first

      expect(element['long-wait-duration-ms']).to eq('1000')
    end
  end

  context 'with wrapper options' do
    it 'renders wrapper with given options' do
      render_inline SpinnerButtonComponent.new(
        wrapper_options: { data: { foo: 'bar' } },
        outline: true,
      ).with_content('')

      expect(page).to have_css('lg-spinner-button[data-foo="bar"]')
    end

    context 'with outline button' do
      it 'renders with both customized class and outline class' do
        rendered = render_inline SpinnerButtonComponent.new(
          wrapper_options: { class: 'example-class' },
          outline: true,
        ).with_content('')

        expect(rendered).to have_css('lg-spinner-button.example-class.spinner-button--outline')
      end
    end
  end
end
