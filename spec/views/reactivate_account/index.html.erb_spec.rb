require 'rails_helper'

RSpec.describe 'reactivate_account/index.html.erb' do
  subject(:rendered) do
    render
  end

  let(:personal_key_generated_at) { Time.zone.parse('2020-04-09T14:03:00Z').utc }

  it 'displays a fallback warning alert when js is off' do
    assign(:personal_key_generated_at, personal_key_generated_at)

    expect(rendered).to have_content(t('instructions.account.reactivate.modal.copy'))
  end

  it 'displays the date the personal key was generated without time' do
    assign(:personal_key_generated_at, personal_key_generated_at)

    expect(rendered).to have_content('April 9, 2020')
  end
end
