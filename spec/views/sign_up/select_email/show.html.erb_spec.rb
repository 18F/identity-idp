require 'rails_helper'

RSpec.describe 'sign_up/select_email/show.html.erb' do
  subject(:rendered) { render }
  let(:email) { 'michael.motorist@email.com' }
  let(:email2) { 'michael.motorist2@email.com' }
  let(:user) { create(:user) }

  before do
    create(:email_address, email: email, user:)
    create(:email_address, email: email2, user:)
    @user_emails = user.confirmed_email_addresses
    @select_email_form = SelectEmailForm.new(user:)
    @sp_name = 'Test Service Provider'
    @can_add_email = true
  end

  it 'renders introduction text' do
    expect(rendered).to have_content(
      strip_tags(t('help_text.select_preferred_email_html', sp: @sp_name)),
    )
  end

  it 'shows all of the emails' do
    expect(rendered).to include('michael.motorist@email.com')
    expect(rendered).to include('michael.motorist2@email.com')
  end

  it 'renders a button to allow users to add email' do
    expect(rendered).to have_link(
      t('account.index.email_add'),
      href: add_email_path(in_select_email_flow: true),
    )
  end

  context 'if user has reached max number of emails' do
    before do
      @can_add_email = false
    end

    it 'does not render add email button' do
      expect(rendered).not_to have_link(
        t('account.index.email_add'),
        href: add_email_path(in_select_email_flow: true),
      )
    end
  end
end
