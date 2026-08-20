require 'rails_helper'

RSpec.describe 'accounts/_piv_cac.html.erb' do
  let(:user) do
    user = create(:user)
    2.times do |n|
      create(
        :piv_cac_configuration,
        user: user,
        name: "Configuration #{n}",
        x509_dn_uuid: "unique-uuid-#{n}",
      )
    end
    user
  end

  let(:user_session) { { auth_events: [] } }

  subject(:rendered) { render partial: 'accounts/piv_cac' }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_session).and_return(user_session)
  end

  it 'renders a list of piv cac configurations' do
    expect(rendered).to have_selector('[role="list"] [role="listitem"]', count: 2)
  end

  describe 'add-piv/cac button bucket-conditional rendering' do
    before do
      # Ensure the add button renders (default max is 2 and the user has 2).
      allow(IdentityConfig.store).to receive(:max_piv_cac_per_account).and_return(10)
    end

    context 'legacy bucket' do
      it 'renders origin/main classes (outline), no nds variant modifiers' do
        expect(rendered).to have_css('.usa-button.usa-button--outline')
        expect(rendered).not_to have_css('.usa-button--secondary')
        expect(rendered).not_to have_css('.usa-button--md')
      end
    end

    context 'nds bucket' do
      before { allow(view).to receive(:nds_layout?).and_return(true) }

      it 'renders variant :secondary + size :md, dropping the legacy outline class' do
        expect(rendered).to have_css('.usa-button.usa-button--secondary.usa-button--md')
        expect(rendered).not_to have_css('.usa-button--outline')
      end
    end
  end
end
