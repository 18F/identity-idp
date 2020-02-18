require 'rails_helper'

feature 'cac proofing present cac step' do
  include CacProofingHelper

  let(:decoded_token) do
    {
      'subject' => 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.1234',
      'card_type' => 'cac',
    }
  end

  before do
    enable_cac_proofing
    sign_in_and_2fa_user
    complete_cac_proofing_steps_before_present_cac_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_cac_proofing_present_cac_step)
  end

  it 'proceeds to the next page' do
    allow(PivCacService).to receive(:decode_token).and_return(decoded_token)

    click_link t('forms.buttons.cac')

    expect(page.current_url.include?("/\?nonce=")).to eq(true)

    visit idv_cac_step_path(step: :present_cac, token: 'foo')

    expect(page.current_path).to eq(idv_cac_proofing_enter_info_step)
  end

  it 'does not proceed to the next page with a bad CAC and allows doc auth' do
    click_link t('forms.buttons.cac')

    expect(page.current_url.include?("/\?nonce=")).to eq(true)

    visit idv_cac_step_path(step: :present_cac, token: 'foo')

    expect(page.current_path).to eq(idv_cac_proofing_present_cac_step)
    expect(page).to have_link(t('cac_proofing.errors.state_id'), href: idv_doc_auth_path)
  end

  it 'does not proceed to the next page if card_type is not CAC' do
    decoded_token_piv = {
      'subject' => 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.1234',
      'card_type' => 'piv',
    }
    allow(PivCacService).to receive(:decode_token).and_return(decoded_token_piv)

    click_link t('forms.buttons.cac')

    expect(page.current_url.include?("/\?nonce=")).to eq(true)

    visit idv_cac_step_path(step: :present_cac, token: 'foo')

    expect(page.current_path).to eq(idv_cac_proofing_present_cac_step)
    expect(page).to have_link(t('cac_proofing.errors.state_id'), href: idv_doc_auth_path)
  end
end
