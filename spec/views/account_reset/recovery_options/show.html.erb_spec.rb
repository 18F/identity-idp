require 'rails_helper'

RSpec.describe 'account_reset/recovery_options/show.html.erb' do
  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('account_reset.recovery_options.header'))

    render
  end

  it 'has button to cancel request' do
    render
    expect(rendered).to have_button t('account_reset.request.no_cancel')
  end

  context 'with new workflow' do
    before do
      allow(IdentityConfig.store).to receive(:updated_account_reset_content).and_return(true)
    end

    it 'renders new account reset options info' do
      render 

      expect(rendered)
        .to have_content(t('account_reset.recovery_options.check_webauthn_platform_header'))
    end
  end

  context 'with old workflow' do
    before do
      allow(IdentityConfig.store).to receive(:updated_account_reset_content).and_return(false)
    end

    it 'renders account reset options info' do
      render 

      expect(rendered)
        .to have_content(t('account_reset.recovery_options.use_device'))
    end
  end
end
