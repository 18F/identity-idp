require 'rails_helper'

RSpec.describe 'two_factor_authentication/sms_opt_in/new.html.erb' do
  let(:phone) { '1-888-867-5309' }
  let(:phone_configuration) { build(:phone_configuration, phone:) }
  let(:phone_number_opt_out) { PhoneNumberOptOut.create_or_find_with_phone(phone) }
  let(:other_mfa_options_url) { nil }
  let(:cancel_url) { '/account' }

  before do
    assign(:phone_configuration, phone_configuration)
    assign(:phone_number_opt_out, phone_number_opt_out)
    assign(:other_mfa_options_url, other_mfa_options_url)
    assign(:cancel_url, cancel_url)
    allow(view).to receive(:user_signing_up?).and_return(false)
  end

  it 'renders the masked phone number' do
    render

    expect(rendered).to have_content('(***) ***-5309')
  end

  context 'other authentication methods' do
    context 'without an other_mfa_options_url' do
      let(:other_mfa_options_url) { nil }

      it 'omits the other auth methods section' do
        render

        expect(rendered).to_not have_content(t('two_factor_authentication.opt_in.cant_use_phone'))
        expect(rendered).to_not have_content(t('two_factor_authentication.login_options_link_text'))
      end
    end

    context 'with an other_mfa_options_url' do
      let(:other_mfa_options_url) { '/other' }

      it 'links to other options' do
        render

        expect(rendered).to have_content(t('two_factor_authentication.opt_in.cant_use_phone'))
        expect(rendered).to have_link(
          t('two_factor_authentication.login_options_link_text'),
          href: other_mfa_options_url,
        )
      end
    end
  end
end
