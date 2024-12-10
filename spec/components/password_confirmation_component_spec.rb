require 'rails_helper'

RSpec.describe PasswordConfirmationComponent, type: :component do
  let(:view_context) { vc_test_controller.view_context }
  let(:form) { SimpleForm::FormBuilder.new('', {}, view_context, {}) }
  let(:options) { { form: } }

  subject(:rendered) do
    render_inline PasswordConfirmationComponent.new(**options)
  end

  it 'renders password fields with expected attributes' do
    expect(rendered).to have_css('[type=password][autocomplete=new-password]', count: 2)
    expect(rendered).to have_field(t('forms.password'), type: :password)
    expect(rendered).to have_field(
      t('components.password_confirmation.confirm_label'),
      type: :password,
    )
    expect(rendered).to have_field(
      t('components.password_confirmation.toggle_label'),
      type: :checkbox,
    )
  end

  context 'with labels passed in' do
    let(:password_label) { 'edited password label' }
    let(:confirmation_label) { 'edited password confirmation label' }
    let(:options) { super().merge(password_label:, confirmation_label:) }

    it 'renders custom password label' do
      expect(rendered).to have_content(password_label)
    end

    it 'renders custom password confirmation label' do
      expect(rendered).to have_content(confirmation_label)
    end
  end

  context 'with forbidden passwords' do
    let(:forbidden_passwords) { ['password'] }
    let(:options) { super().merge(forbidden_passwords:) }

    it 'forwards forbidden passwords to rendered password strength component' do
      expect(PasswordStrengthComponent).to receive(:new)
        .with(hash_including(forbidden_passwords:))
        .and_call_original

      rendered
    end
  end
end
