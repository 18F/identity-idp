require 'rails_helper'

RSpec.describe MfaSelectionComponent, type: :component do
  include SimpleForm::ActionViewExtensions::FormHelper

  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, controller) }
  let(:form_object) { User.new }
  let(:presenter) {TwoFactorOptionsPresenter.new(user_agent: nil)}
  let(:form_builder) do
    SimpleForm::FormBuilder.new(form_object.model_name.param_key, form_object, view_context, {})
  end

  let(:options) do
  {
    form: form_builder,
    option: presenter.options[4],
  }.compact
end

  subject(:rendered) do
    render_inline(described_class.new(**options))
  end

  it 'renders an lg-validated-field tag' do
    expect(rendered).to have_css('lg-validated-field')
  end

  context 'before selecting options' do
    it 'does not display any errors' do
      expect(rendered).to_not have_css('.checkbox__invalid')
      expect(rendered).to_not have_css('.checkbox__alert')
    end
  end

end