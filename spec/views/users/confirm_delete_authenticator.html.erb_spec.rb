require 'rails_helper'

RSpec.describe 'users/_confirm_delete_authenticator.html.erb' do
  let(:heading) { 'Are you sure you want to delete this authentication app?' }
  let(:caution) { 'If you delete this authentication app, you will no longer be able to sign in.' }
  let(:delete_url) { '/manage/auth_app/1' }
  let(:delete_label) { 'Delete this device' }
  let(:cancel_url) { '/manage/auth_app/1' }

  it 'renders a warning alert with the consequence copy' do
    render(
      partial: 'users/confirm_delete_authenticator',
      locals: { heading:, caution:, delete_url:, delete_label:, cancel_url: },
    )

    expect(rendered).to have_content(caution)
  end

  it 'renders a destructive delete button and a cancel link' do
    render(
      partial: 'users/confirm_delete_authenticator',
      locals: { heading:, caution:, delete_url:, delete_label:, cancel_url: },
    )

    expect(rendered).to have_button(delete_label)
    expect(rendered).to have_link(t('links.cancel'), href: cancel_url)
  end
end
