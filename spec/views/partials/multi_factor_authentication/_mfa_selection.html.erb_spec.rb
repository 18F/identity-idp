require 'rails_helper'

describe 'partials/multi_factor_authentication/_mfa_selection.html.erb' do
  include SimpleForm::ActionViewExtensions::FormHelper
  include Devise::Test::ControllerHelpers

  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, controller) }
  let(:form_object) { User.new }
  let(:presenter) { TwoFactorOptionsPresenter.new(user_agent: nil) }
  let(:form_builder) do
    SimpleForm::FormBuilder.new(form_object.model_name.param_key, form_object, view_context, {})
  end

  subject(:rendered) do
    render partial: 'mfa_selection', locals: {
      form: form_builder,
      option: presenter.options[4],
    }
  end

  it 'renders an lg-validated-field tag' do
    expect(rendered).to have_css('.mfa-selection')
  end

  context 'before selecting options' do
    it 'does not display any errors' do
      expect(rendered).to_not have_css('.checkbox__invalid')
    end
  end
end
