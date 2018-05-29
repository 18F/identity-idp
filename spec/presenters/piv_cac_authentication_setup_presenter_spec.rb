require 'rails_helper'

describe PivCacAuthenticationSetupPresenter do
  let(:presenter) { described_class.new(form) }
  let(:form) do
    OpenStruct.new(
    )
  end

  describe '#title' do
    let(:expected_title) { t('titles.piv_cac_setup.new' ) }

    it { expect(presenter.title).to eq expected_title }
  end

  describe '#heading' do
    let(:expected_heading) { t('headings.piv_cac_setup.new' ) }

    it { expect(presenter.heading).to eq expected_heading }
  end

  describe '#description' do
    let(:expected_description) { t('forms.piv_cac_setup.piv_cac_intro_html') }

    it { expect(presenter.description).to eq expected_description }
  end
end
