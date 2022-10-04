require 'rails_helper'

feature 'Generate key pair on Sign in' do
  let(:percentage) { 0 }

  before do
    allow(IdentityConfig.store).to receive(:key_pair_generation_percent).and_return(percentage)
    AbTests.reload_ab_test_initializer!
  end

  after do
    allow(IdentityConfig.store).to receive(:key_pair_generation_percent).and_call_original
    AbTests.reload_ab_test_initializer!
  end

  context 'key pair generation disabled' do
    it 'does not include a key pair generator on the page' do
      visit '/'
      expect(page).not_to have_css('lg-key-pair-generator')
    end
  end

  context 'key pair generation enabled' do
    let(:percentage) { 100 }

    it 'includes a key pair generator on the page' do
      visit '/'
      expect(page).to have_css('lg-key-pair-generator')
    end
  end
end
