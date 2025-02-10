require 'rails_helper'

RSpec.describe PivCacRecommendedPresenter do
  let(:user) { create(:user, email: 'example@example.gov') }
  let(:presenter) { described_class.new(user) }

  describe '#skip_text' do
    context 'when existing user' do
      let(:user) { create(:user, :with_phone, { email: 'example@example.mil' }) }
      it 'should return skip text' do
        expect(presenter.skip_text).to eq(t('two_factor_authentication.piv_cac_upsell.skip'))
      end
    end

    context 'when user has no mfa methods yet' do
      let(:user) { create(:user, email: 'example@example.mil') }
      it 'should return choose another method text' do
        expect(presenter.skip_text).to eq(
          t('two_factor_authentication.piv_cac_upsell.choose_other_method'),
        )
      end
    end
  end
end
