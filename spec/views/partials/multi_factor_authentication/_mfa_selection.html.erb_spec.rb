require 'rails_helper'

describe 'partials/multi_factor_authentication/_mfa_selection.html.erb' do
  include SimpleForm::ActionViewExtensions::FormHelper
  include Devise::Test::ControllerHelpers

  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, controller) }
  let(:user) { create(:user) }
  let(:form_object) { user }
  let(:presenter) { TwoFactorOptionsPresenter.new(user_agent: nil, user: user) }
  let(:form_builder) do
    SimpleForm::FormBuilder.new(form_object.model_name.param_key, form_object, view_context, {})
  end

  context 'before selecting options' do
    subject(:rendered) do
      render partial: 'mfa_selection',
             locals: {
               form: form_builder,
               option: presenter.options[4],
             }
    end
    it 'does not display any errors' do
      expect(rendered).to_not have_css('.checkbox__invalid')
    end

    it 'renders a field with mfa-selection class' do
      expect(rendered).to have_css('.mfa-selection')
    end
  end

  context 'user already setup an mfa configuration and is returning to create a second' do
    let(:user) { create(:user, :with_authentication_app) }
    let(:form_object) { user }
    let(:presenter) { TwoFactorOptionsPresenter.new(user_agent: nil, user: user) }
    let(:form_builder) do
      SimpleForm::FormBuilder.new(form_object.model_name.param_key, form_object, view_context, {})
    end
    subject(:rendered) do
      render partial: 'mfa_selection',
             locals: {
               form: form_builder,
               option: presenter.options.find do |option|
                         option.is_a?(TwoFactorAuthentication::AuthAppSelectionPresenter)
                       end,
             }
    end

    it 'shows a disabled checkbox for the configuration already created' do
      expect(rendered).to have_field('two_factor_options_form[selection][]', disabled: true)
    end

    it 'shows a checked checkbox for the configuration already created' do
      expect(rendered).to have_field(
        'two_factor_options_form[selection][]',
        disabled: true,
        checked: true,
      )
    end

    it 'the checkbox for the configuration created communicates it is already created' do
      expect(rendered).to have_content(
        t(
          'two_factor_authentication.two_factor_choice_options.configurations_added',
          count: 1,
        ),
      )
    end
  end
end
