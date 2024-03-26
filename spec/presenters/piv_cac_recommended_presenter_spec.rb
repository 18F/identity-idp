require 'rails_helper'

RSpec.describe PivCacRecommendedPresenter do
  let(:user) { create(:user, email: 'example@example.gov') }
  let(:presenter) { described_class.new(user) }

  describe '#info' do
    context 'when is a gov email' do
      context 'when existing user' do
        let(:user) { create(:user, :with_phone, { email: 'example@example.gov' }) }
        it 'should match existing user .gov text' do
          expect(presenter.info).to eq(
            t(
              'two_factor_authentication.piv_cac_upsell.existing_user_info',
              email_type: '.gov',
            ),
          )
        end
      end

      context 'when user has no mfa methods' do
        let(:user) { create(:user, email: 'example@example.gov') }
        it 'should match new user .gov text' do
          expect(presenter.info).to eq(
            t(
              'two_factor_authentication.piv_cac_upsell.new_user_info',
              email_type: '.gov',
            ),
          )
        end
      end
    end

    context 'when user has a .mil email' do
      context 'when existing user' do
        let(:user) { create(:user, :with_phone, { email: 'example@example.mil' }) }
        it 'should match existing user .mil text' do
          expect(presenter.info).to eq(
            t(
              'two_factor_authentication.piv_cac_upsell.existing_user_info',
              email_type: '.mil',
            ),
          )
        end
      end

      context 'when user has no mfa methods yet' do
        let(:user) { create(:user, email: 'example@example.mil') }
        it 'should match new user .mil text' do
          expect(presenter.info).to eq(
            t(
              'two_factor_authentication.piv_cac_upsell.new_user_info',
              email_type: '.mil',
            ),
          )
        end
      end
    end
  end

  describe '#email_type' do
    context 'when is gov email' do
      it 'should return .gov' do
        expect(presenter.email_type).to eq('.gov')
      end
    end

    context 'when .mil email' do
			let(:user) { create(:user, email: 'example@example.mil') }
      it 'should return .mil' do
        expect(presenter.email_type).to eq('.mil')
      end
    end
  end

  describe '#skip_type' do
    context 'when existing user' do
      let(:user) { create(:user, :with_phone, { email: 'example@example.mil' }) }
      it 'should return skip text' do
        expect(presenter.skip_text).to eq(t('mfa.skip'))
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
