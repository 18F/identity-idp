require 'rails_helper'

RSpec.describe 'sign_up/email_resend/new.html.erb' do
  before do
    @user = User.new
    @resend_email_confirmation_form = ResendEmailConfirmationForm.new
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.confirmations.new'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.confirmations.new'))
  end
end
