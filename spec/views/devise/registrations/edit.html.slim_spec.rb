require 'rails_helper'

describe 'devise/registrations/edit.html.slim' do
  before do
    @update_user_profile_form = UpdateUserProfileForm.new(build_stubbed(:user))
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('upaya.titles.registrations.edit'))

    render
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end
end
