require 'rails_helper'

describe 'reactivate_account/index.html.erb' do
  subject(:rendered) do
    render
  end

  let(:personal_key_generated_at) { Time.zone.parse('2022-02-9T03:29:43+10:00') }

  it 'displays a fallback warning alert when js is off' do
    assign(:personal_key_generated_at, personal_key_generated_at)

    expect(rendered).to have_content(t('instructions.account.reactivate.modal.copy'))
  end

  it 'displays the date the personal key was generated' do
    assign(:personal_key_generated_at, personal_key_generated_at)

    expect(rendered).to have_content(
      t(
        'users.personal_key.generated_on_html',
        date: I18n.l(personal_key_generated_at, format: '%B %-d, %Y'),
      ),
    )
  end
end
