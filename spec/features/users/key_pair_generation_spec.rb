require 'rails_helper'

feature 'Generate key pair on Sign in' do
  before do
    stub_const('AbTests::KEY_PAIR_GENERATION', FakeAbTestBucket.new)
  end

  context 'key pair generation disabled' do
    before do
      AbTests::KEY_PAIR_GENERATION.assign_all(:default)
    end

    it 'does not include a key pair generator on the page' do
      visit '/'
      expect(page).not_to have_css('lg-key-pair-generator')
    end
  end

  context 'key pair generation enabled' do
    before do
      AbTests::KEY_PAIR_GENERATION.assign_all(:key_pair_group)
    end

    it 'includes a key pair generator on the page' do
      visit '/'
      expect(page).to have_css('lg-key-pair-generator')
    end
  end
end
