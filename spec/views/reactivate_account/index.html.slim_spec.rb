require 'rails_helper'

describe 'reactivate_account/index.html.slim' do
  it 'displays a fallback warning alert when js is off' do
    render

    expect(rendered).to have_content(t('instructions.account.reactivate.modal.copy'))
  end
end
