require 'rails_helper'

RSpec.describe 'users/service_provider_inactive/index.html.erb' do
  let(:sp_name) { t('service_providers.errors.generic_sp_name') }

  subject(:rendered) { render }

  before do
    assign(:sp_name, sp_name)
  end

  it 'renders heading' do
    expect(rendered).to have_css(
      'h1',
      text: t('service_providers.errors.inactive.heading', sp_name:, app_name: APP_NAME),
    )
  end
end
