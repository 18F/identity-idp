require 'rails_helper'

RSpec.describe 'users/phone_setup/spam_protection.html.erb' do
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
      t('two_factor_authentication.learn_more'),
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

    it 'does not render cancel option' do
      expect(rendered).to_not have_link(
        t('links.cancel'),
        href: account_path,
      )
    end
  end

  context 'fully registered user adding new phone' do
    let(:user) { create(:user, :fully_registered) }

    it 'does not render additional troubleshooting option to two factor options' do
      expect(rendered).to_not have_link(
        t('two_factor_authentication.login_options_link_text'),
        href: two_factor_options_path,
      )
    end

    it 'renders cancel option' do
      expect(rendered).to have_link(
        t('links.cancel'),
        href: account_path,
      )
    end
  end

  context 'with configured recaptcha site key' do
    before do
      allow(IdentityConfig.store).to receive(:recaptcha_site_key_v2).and_return('key')
    end

    it 'renders recaptcha script' do
      expect(rendered).to have_css(
        'script[src="https://www.google.com/recaptcha/api.js"]',
        visible: :all,
      )
    end

    context 'with recaptcha enterprise' do
      before do
        allow(FeatureManagement).to receive(:recaptcha_enterprise?).and_return(true)
      end

      it 'renders recaptcha script' do
        expect(rendered).to have_css(
          'script[src="https://www.google.com/recaptcha/enterprise.js"]',
          visible: :all,
        )
      end
    end
  end
end
