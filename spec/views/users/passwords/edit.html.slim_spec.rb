require 'rails_helper'

describe 'users/passwords/edit.html.slim' do
  before do
    user = User.new
    allow(view).to receive(:current_user).and_return(user)
    @update_user_password_form = UpdateUserPasswordForm.new(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.edit_info.password'))

    render
  end

  it 'has a localized heading' do
    render

    expect(rendered).to have_content t('headings.edit_info.password')
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end

  it 'contains minimum password length requirements' do
    render

    expect(rendered).to have_content t(
      'instructions.password.info.lead', min_length: Devise.password_length.first
    )
  end
end
