require 'rails_helper'

RSpec.describe PasswordConfirmationComponent, type: :component do
  let(:view_context) { vc_test_controller.view_context }
  let(:form) { SimpleForm::FormBuilder.new('', {}, view_context, {}) }

  subject(:rendered) do
    render_inline PasswordConfirmationComponent.new(form:)
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
end
