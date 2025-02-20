require 'rails_helper'

RSpec.describe 'users/passwords/edit.html.erb' do
  let(:required_password_change) { false }

  before do
    user = User.new
    allow(view).to receive(:current_user).and_return(user)
    @update_user_password_form = UpdateUserPasswordForm.new(user: user)
    @update_password_presenter = UpdatePasswordPresenter.new(
      user: user,
      required_password_change: required_password_change,
    )
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.edit_info.password'))

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

    expect(rendered).to have_content strip_tags(
      t(
        'instructions.password.info.lead_html',
        min_length: Devise.password_length.min,
      ),
    )
  end

  it 'has aria described by' do
    render

    expect(rendered).to have_selector('[aria-describedby="password-strength password-description"]')
  end

  context 'required password change' do
    let(:required_password_change) { true }

    it 'has alert component content for required password change' do
      render

      expect(rendered).to have_content t('users.password_compromised.warning', app_name: APP_NAME)
    end

    it 'has a submit content for submission page' do
      render

      expect(rendered).to have_content I18n.t('forms.passwords.edit.buttons.submit')
    end

    it 'does not have cancel content for submission page' do
      render
      expect(rendered).to_not have_content(t('links.cancel'))
    end

    it 'aria described by is blank' do
      render

      expect(rendered).to_not have_selector(
        '[aria-describedby="password-strength password-description"]',
      )
    end
  end
end
