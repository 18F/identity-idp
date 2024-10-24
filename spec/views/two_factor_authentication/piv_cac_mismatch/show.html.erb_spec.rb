require 'rails_helper'

RSpec.describe 'two_factor_authentication/piv_cac_mismatch/show.html.erb' do
  let(:has_other_authentication_methods) {}
  let(:piv_cac_required) {}

  subject(:rendered) { render }

  before do
    @has_other_authentication_methods = has_other_authentication_methods
    @piv_cac_required = piv_cac_required
    allow(view).to receive(:user_session).and_return({})
  end

  context 'when user does not have other authentication methods' do
    let(:has_other_authentication_methods) { false }

    it 'renders instructions with a link to delete their account' do
      expect(rendered).to have_content(
        t(
          'two_factor_authentication.piv_cac_mismatch.instructions_no_other_method',
          app_name: APP_NAME,
        ),
      )
      expect(rendered).to have_link(
        t('two_factor_authentication.piv_cac_mismatch.delete_account'),
        href: account_reset_recovery_options_url,
      )
    end
  end

  context 'when user has other authentication methods' do
    let(:has_other_authentication_methods) { true }

    it 'renders instructions with a link to authenticate' do
      expect(rendered).to have_content(t('two_factor_authentication.piv_cac_mismatch.instructions'))
      expect(rendered).to have_button(t('two_factor_authentication.piv_cac_mismatch.cta'))
    end

    context 'when piv cac is required' do
      let(:piv_cac_required) { true }

      it 'does not provide an option to skip setting up piv/cac' do
        expect(rendered).not_to have_button(t('two_factor_authentication.piv_cac_mismatch.skip'))
      end
    end

    context 'when piv cac is not required' do
      let(:piv_cac_required) { false }

      it 'provides an option to skip setting up piv/cac' do
        expect(rendered).to have_button(t('two_factor_authentication.piv_cac_mismatch.skip'))
      end
    end
  end
end
