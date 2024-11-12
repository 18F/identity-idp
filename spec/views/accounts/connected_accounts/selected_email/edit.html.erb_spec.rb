require 'rails_helper'

RSpec.describe 'accounts/connected_accounts/selected_email/edit.html.erb' do
  let(:identity) { create(:service_provider_identity, :active) }
  let(:user) do
    create(
      :user,
      email_addresses: [
        create(:email_address),
        create(:email_address),
        create(:email_address, :unconfirmed),
      ],
      identities: [identity],
    )
  end

  subject(:rendered) { render }

  before do
    allow(view).to receive(:current_user).and_return(user)
    @identity = identity
    @select_email_form = SelectEmailForm.new(user:, identity:)
  end

  it 'renders introduction text' do
    expect(rendered).to have_content(
      strip_tags(t('help_text.select_preferred_email_html', sp: identity.display_name)),
    )
  end

  it 'renders a list of the users email addresses as radio options' do
    allow(self).to receive(:page).and_return(Capybara.string(rendered))
    inputs = page.find_all('[type="radio"]')
    expect(inputs.count).to eq(2)
    expect(inputs).to be_logically_grouped(t('titles.select_email'))
    expect(rendered).to have_content(identity.display_name)
  end
end
