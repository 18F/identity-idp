require 'rails_helper'

describe PivCacAuthenticationSetupErrorPresenter do
  let(:presenter) { described_class.new(form) }
  let(:form) do
    OpenStruct.new(
      error_type: error
    )
  end
  let(:error) { 'certificate.none' }

  describe '#error' do
    it 'reflects the form' do
      expect(presenter.error).to eq form.error_type
    end
  end

  describe '#may_select_another_certificate?' do
    let(:may_select_another_certificate) { presenter.may_select_another_certificate? }
    context 'when token.invalid' do
      let(:error) { 'token.invalid' }

      it { expect(may_select_another_certificate).to be_truthy }
    end

    context 'not when certificate.none' do
      let(:error) { 'certificate.none' }

      it { expect(may_select_another_certificate).to be_falsey }
    end

    context 'when certificate.*' do
      let(:error) { 'certificate.revoked' }

      it { expect(may_select_another_certificate).to be_truthy }
    end
  end

  describe '#title' do
    let(:expected_title) { t('titles.piv_cac_setup.' + error ) }

    it { expect(presenter.title).to eq expected_title }
  end

  describe '#heading' do
    let(:expected_heading) { t('headings.piv_cac_setup.' + error ) }

    it { expect(presenter.heading).to eq expected_heading }
  end

  describe '#description' do
    let(:expected_description) { t('forms.piv_cac_setup.' + error + '_html') }

    it { expect(presenter.description).to eq expected_description }
  end
end
