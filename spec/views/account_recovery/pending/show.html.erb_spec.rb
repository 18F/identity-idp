require 'rails_helper'

RSpec.describe 'account_recovery/pending/show.html.erb' do
  before do
    assign(:waiting_period_interval, '1 day')
  end

  it 'explains that leaving the page does not cancel the request' do
    render

    expect(rendered).to include(t('account_recovery.pending.leaving_does_not_cancel'))
    expect(rendered).to have_link(
      t('account_recovery.pending.return_home'),
      href: root_path,
    )
  end
end
