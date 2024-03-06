require 'rails_helper'

RSpec.describe Idv::WelcomePresenter do
  subject(:presenter) { Idv::WelcomePresenter.new(decorated_sp_session) }

  let(:sp) do
    build(:service_provider)
  end

  let(:sp_session) do
    {}
  end

  let(:decorated_sp_session) do
    ServiceProviderSession.new(
      sp: sp,
      view_context: nil,
      sp_session: sp_session,
      service_provider_request: nil,
    )
  end

  it 'gives us the correct sp_name' do
    expect(presenter.sp_name).to eq('Test Service Provider')
  end

  it 'gives us the correct title' do
    expect(presenter.title).to eq(t('doc_auth.headings.welcome', sp_name: 'Test Service Provider'))
  end

  context 'when a selfie is not required' do
    it 'says so' do
      expect(presenter.selfie_required?).to be(false)
    end
  end

  context 'when a selfie is required' do
    let(:sp_session) do
      { biometric_comparison_required: true }
    end

    before do
      allow(IdentityConfig.store).to receive(:doc_auth_selfie_capture_enabled).and_return(true)
    end

    it 'says so' do
      expect(presenter.selfie_required?).to be(true)
    end
  end
end
