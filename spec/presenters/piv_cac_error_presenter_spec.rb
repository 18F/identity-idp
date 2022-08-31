require 'rails_helper'

describe PivCacErrorPresenter do
  let(:view) { double(:view, link_to: '') }
  let(:presenter) { described_class.new(error: error, view: view, try_again_url: '') }
  let(:error) { 'certificate.none' }

  describe '#error' do
    it 'reflects the form' do
      expect(presenter.error).to eq error
    end
  end

  describe '#title' do
    let(:expected_title) { t('headings.piv_cac.certificate.none') }

    it { expect(presenter.title).to eq expected_title }
  end

  describe '#heading' do
    let(:expected_heading) { t('headings.piv_cac.certificate.none') }

    it { expect(presenter.heading).to eq expected_heading }
  end

  describe '#description' do
    let(:expected_description) do
      t(
        'instructions.mfa.piv_cac.no_certificate_html',
        try_again: view.link_to(t('instructions.mfa.piv_cac.try_again'), ''),
      )
    end

    it { expect(presenter.description).to eq expected_description }
  end
end
