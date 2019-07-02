require 'rails_helper'

describe SetupPresenter do
  let(:user) { create(:user) }
  let(:presenter) { described_class.new(user, false) }

  describe 'shows correct step indication' do
    context 'with signed in user adding additional method' do
      let(:user) { build(:user, :signed_up) }
      let(:presenter) { described_class.new(user, true) }

      it 'does not show step count' do
        expect(presenter.steps_visible?).to eq false
      end
    end

    context 'with user signing up who has not chosen first option' do
      it 'shows user is on step 3 of 4' do
        expect(presenter.step).to eq '3'
      end
    end

    context 'with user signing up who has chosen first option' do
      let(:user) { build(:user, :with_webauthn) }

      it 'shows user is on step 4 of 4' do
        expect(presenter.step).to eq '4'
      end
    end
  end
end
