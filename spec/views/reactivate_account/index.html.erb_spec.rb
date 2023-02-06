require 'rails_helper'

describe 'reactivate_account/index.html.erb' do
  subject(:rendered) do
    render
  end

  let(:presenter_class) { AccountShowPresenter }
  let(:personal_key_generated_at) { Time.zone.now }
  let(:presenter) do
    instance_double(
      presenter_class,
      personal_key_generated_at: personal_key_generated_at,
    )
  end

  it 'displays a fallback warning alert when js is off' do
    assign(:presenter, presenter)

    expect(rendered).to have_content(t('instructions.account.reactivate.modal.copy'))
  end

  it 'displays the date the personal key was generated' do
    assign(:presenter, presenter)

    expect(rendered).to have_content(
      t(
        'users.personal_key.generated_on_html',
        date: I18n.l(Time.zone.today, format: '%B %d, %Y'),
      ),
    )
  end
end
