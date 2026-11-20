require 'rails_helper'

RSpec.describe 'users/edit_phone/edit.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user, :with_phone) }
  let(:phone_configuration) { user.phone_configurations.first }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    assign(:phone_configuration, phone_configuration)
    assign(:edit_phone_form, EditPhoneForm.new(user, phone_configuration))
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.edit_info.phone'))

    render
  end

  it 'renders the legacy heading and confirm change submit' do
    render

    expect(rendered).to have_css('h1', text: t('headings.edit_info.phone'))
    expect(rendered).to have_button(t('forms.buttons.submit.confirm_change'))
  end

  it 'does not render the NDS form page in the default layout' do
    render

    expect(rendered).to_not have_css('.auth--form-page')
  end

  context 'in the NDS layout' do
    let(:form_path) { manage_phone_path(id: phone_configuration.id) }

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the Figma heading with the masked phone in the signed-in header layout' do
      render

      expect(view.content_for(:nds_account_header)).to eq('true')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('nds.dashboard_account.manage_phone_heading'),
      )
      expect(rendered).to have_css(
        '.auth__intro-description strong',
        text: EditPhoneForm.new(user, phone_configuration).masked_phone,
      )
    end

    it 'puts the delivery preference and default number fields in the update form' do
      render

      expect(rendered).to have_css(
        "form#edit-phone-form[action='#{form_path}'] input[name=_method][value=put]",
        visible: :all,
      )
      expect(rendered).to have_css(
        "#edit-phone-form fieldset input[type=radio][name='edit_phone_form[delivery_preference]']" \
          "[value=sms][checked]",
      )
      expect(rendered).to have_css(
        "#edit-phone-form input[type=radio][name='edit_phone_form[delivery_preference]']" \
          "[value=voice]",
      )
      expect(rendered).to have_css('label.radio__label', text: t('nds.phone_setup.delivery.sms'))
      expect(rendered).to have_css('label.radio__label', text: t('nds.phone_setup.delivery.voice'))
      expect(rendered).to have_css(
        "#edit-phone-form input[type=checkbox][name='edit_phone_form[make_default_number]']" \
          "[value=otp_make_default_number]",
      )
      expect(rendered).to have_css(
        'label.checkbox__label',
        text: t('two_factor_authentication.otp_make_default_number.label'),
      )
    end

    it 'submits the update form with Continue and cancels to the account page' do
      render

      expect(rendered).to have_css(
        '.auth__actions button[type=submit][form=edit-phone-form]',
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_link(
        t('links.cancel'),
        href: account_path,
        class: 'usa-button--tertiary',
      )
    end

    context 'with the only phone' do
      it 'disables the default checkbox, explains why, and does not offer to remove it' do
        render

        expect(rendered).to have_css(
          "input[name='edit_phone_form[make_default_number]'][disabled][checked]",
        )
        expect(rendered).to have_css(
          '.checkbox__label-description',
          text: t('nds.dashboard_account.one_phone_default_info'),
        )
        expect(rendered).to_not have_button(t('nds.dashboard_account.remove_phone'))
      end
    end

    context 'with a second phone' do
      let(:phone_configuration) do
        create(:phone_configuration, user:, phone: '+1 703-555-1214')
      end

      before { user.reload }

      it 'enables the default checkbox and removes the phone with a separate DELETE form' do
        render

        expect(rendered).to_not have_css(
          "input[name='edit_phone_form[make_default_number]'][disabled]",
        )
        expect(rendered).to_not have_css('.checkbox__label-description')
        expect(rendered).to have_css(
          ".auth__actions form[action='#{form_path}'] input[name=_method][value=delete]",
          visible: :all,
        )
        expect(rendered).to have_css(
          '.auth__actions form button.usa-button--tertiary.account__danger-action',
          text: t('nds.dashboard_account.remove_phone'),
        )
      end
    end
  end
end
