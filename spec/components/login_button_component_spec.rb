require 'rails_helper'

RSpec.describe LoginButtonComponent, type: :component do
  include ActionView::Context
  include ActionView::Helpers::TagHelper

  let(:options) { {} }

  subject(:rendered) do
    render_inline LoginButtonComponent.new(**options)
  end

  it 'renders button text' do
    rendered
    element = page.find_css('.login-button').first
    expect(element.text.squish).to have_text('Sign in with Login.gov')
  end

  it 'renders with design system classes and default color' do
    expect(rendered).to have_css('button.usa-button.login-button.login-button--primary')
  end

  context 'as big' do
    let(:options) { { big: true } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.login-button.usa-button.usa-button--big')
    end
  end

  context 'as darker color' do
    let(:options) { { color: 'primary-darker' } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.login-button.login-button--primary-darker')
    end
  end

  context 'as lighter color' do
    let(:options) { { color: 'primary-lighter' } }

    it 'renders with design system classes' do
      expect(rendered).to have_css('button.usa-button.login-button.login-button--primary-lighter')
    end
  end

  it 'validates color' do
    expect do
      render_inline LoginButtonComponent.new(color: 'foo')
    end.to raise_error(ActiveModel::ValidationError)
  end

  context 'with tag options' do
    it 'renders as attributes' do
      rendered = render_inline LoginButtonComponent.new(
        type: :button,
        class: 'my-custom-class',
        data: { foo: 'bar' },
      )

      expect(rendered).to have_css('.usa-button.my-custom-class[type="button"][data-foo="bar"]')
    end
  end
end
