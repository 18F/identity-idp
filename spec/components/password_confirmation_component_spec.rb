require 'rails_helper'

RSpec.describe PasswordConfirmationComponent, type: :component do
  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, controller) }
  let(:form) { SimpleForm::FormBuilder.new('', {}, view_context, {}) }

  subject(:rendered) do
    render_inline PasswordConfirmationComponent.new(form:)
  end

  it 'renders password fields with expected attributes' do
    expect(rendered).to have_css('[type=password][autocomplete=new-password]', count: 2)
  end
end
