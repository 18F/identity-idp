require 'rails_helper'

RSpec.describe 'account_reset/request/show.html.erb' do
  before do
    user = create(:user, :fully_registered, :with_personal_key)
    allow(view).to receive(:current_user).and_return(user)
    allow(IdentityConfig.store).to receive(:updated_account_reset_content).and_return(false)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('account_reset.request.title'))

    render
  end

  it 'has button to delete' do
    render
    expect(rendered).to have_button t('account_reset.request.yes_continue')
  end

  context 'with new account reset workflow' do
    before do
      allow(IdentityConfig.store).to receive(:updated_account_reset_content).and_return(true)
    end

    it 'renders new workflow content' do
      render

      expect(rendered).to have_content(strip_tags(t('account_reset.request.delete_email1_html')))
    end
  end

  context 'with old account reset workflow' do
    before do
      allow(IdentityConfig.store).to receive(:updated_account_reset_content).and_return(false)
    end

    it 'renders old workflow content' do 
      render

      expect(rendered).to have_content(t('account_reset.request.info').first)
    end
  end
end
