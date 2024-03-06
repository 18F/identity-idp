require 'rails_helper'

RSpec.describe Idv::WelcomePresenter do
  subject(:presenter) { Idv::WelcomePresenter.new(decorated_sp_session) }

  let(:sp) do
    build(:service_provider)
  end

  let(:decorated_sp_session) do
    ServiceProviderSession.new(
      sp: sp,
      view_context: nil,
      sp_session: {},
      service_provider_request: nil,
    )
  end

  it 'gives us the correct sp_name' do
    expect(presenter.sp_name).to eq('Test Service Provider')
  end
end
