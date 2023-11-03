require 'rails_helper'

RSpec.describe 'users/backup_code_setup/index.html.erb' do
  let(:user) { build(:user) }

  before do
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(
      t('forms.backup_code.are_you_sure_title'),
    )

    render
  end
end
