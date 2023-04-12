require 'rails_helper'

describe 'users/phone_setup/spam_protection.html.erb' do
  let(:user) { build_stubbed(:user) }
  let(:form) { NewPhoneForm.new(user:) }
  let(:locals) { {} }

  subject(:rendered) { render(template: 'users/phone_setup/spam_protection', locals:) }

  before do
    @new_phone_form = form
  end

  it 'renders hidden form inputs' do
    expect(rendered).to have_field('new_phone_form[phone]', type: :hidden)
    expect(rendered).to have_field('new_phone_form[international_code]', type: :hidden)
    expect(rendered).to have_field('new_phone_form[otp_delivery_preference]', type: :hidden)
    expect(rendered).to have_field('new_phone_form[otp_make_default_number]', type: :hidden)
    expect(rendered).to have_field('new_phone_form[recaptcha_version]', type: :hidden, with: '2')
    expect(rendered).to have_field('new_phone_form[recaptcha_token]', type: :hidden)
  end

  it 'has expected troubleshooting options' do
    expect(rendered).to have_link(
      t('two_factor_authentication.phone_verification.troubleshooting.learn_more'),
      href: help_center_redirect_path(
        category: 'get-started',
        article: 'authentication-options',
        flow: :two_factor_authentication,
        step: :phone_setup_spam_protection,
      ),
    )
    expect(rendered).not_to have_link(t('two_factor_authentication.login_options_link_text'))
  end

  context 'with two factor options path' do
    let(:two_factor_options_path) { root_path }
    let(:locals) { { two_factor_options_path: } }

    it 'renders additional troubleshooting option to two factor options' do
      expect(rendered).to have_link(
        t('two_factor_authentication.login_options_link_text'),
        href: two_factor_options_path,
      )
    end
  end
end
