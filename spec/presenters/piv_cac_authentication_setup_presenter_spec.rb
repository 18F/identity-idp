require 'rails_helper'

describe PivCacAuthenticationSetupPresenter do
  let(:user) { create(:user) }
  let(:presenter) { described_class.new(user, false, form) }
  let(:form) do
    OpenStruct.new
  end

  describe '#title' do
    let(:expected_title) { t('titles.piv_cac_setup.new') }

    it { expect(presenter.title).to eq expected_title }
  end

  describe '#heading' do
    let(:expected_heading) { t('headings.piv_cac_setup.new') }

    it { expect(presenter.heading).to eq expected_heading }
  end

  describe '#description' do
    let(:expected_description) { t('forms.piv_cac_setup.piv_cac_intro_html') }

    it { expect(presenter.description).to eq expected_description }
  end

  describe 'shows correct step indication' do
    context 'with signed in user adding additional method' do
      let(:user) { build(:user, :signed_up) }
      let(:presenter) { described_class.new(user, true, form) }

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
