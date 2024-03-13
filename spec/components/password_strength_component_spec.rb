require 'rails_helper'

RSpec.describe PasswordStrengthComponent, type: :component do
  let(:input_id) { 'input' }
  let(:options) { { input_id: } }

  subject(:rendered) { render_inline PasswordStrengthComponent.new(**options) }

  it 'renders with default attributes' do
    element = rendered.at_css('lg-password-strength')

    expect(element.attr('input-id')).to eq('input')
    expect(element.attr('minimum-length')).to eq('12')
    expect(element.attr('forbidden-passwords')).to eq('[]')
    expect(element.attr('class')).to eq('display-none')
  end

  context 'with customized options' do
    let(:minimum_length) { 10 }
    let(:forbidden_passwords) { ['password'] }
    let(:tag_options) { { class: 'example-class', data: { foo: 'bar' } } }
    let(:options) { super().merge(minimum_length:, forbidden_passwords:, **tag_options) }

    it 'renders with customized option attributes' do
      element = rendered.at_css('lg-password-strength')

      expect(element.attr('minimum-length')).to eq('10')
      expect(element.attr('forbidden-passwords')).to eq('["password"]')
      expect(element.attr('class').split(' ')).to match_array(['example-class', 'display-none'])
      expect(element.attr('data-foo')).to eq('bar')
    end
  end
end
