require 'rails_helper'

RSpec.describe Idv::ByMail::SpFollowUpPresenter do
  let(:sp_name) { 'Test SP' }
  let(:service_provider) { create(:service_provider, friendly_name: sp_name) }
  let(:user) do
    create(
      :profile,
      :active,
      initiating_service_provider: service_provider,
    ).user
  end

  subject(:presenter) { described_class.new(current_user: user) }

  describe '#heading' do
    it 'interpolates the SP name' do
      expect(presenter.heading).to eq(
        t('idv.by_mail.sp_follow_up.heading', service_provider: sp_name),
      )
    end
  end

  describe '#body' do
    it 'interpolates the SP name' do
      expect(presenter.body).to eq(
        t('idv.by_mail.sp_follow_up.body', service_provider: sp_name, app_name: APP_NAME),
      )
    end
  end
end
