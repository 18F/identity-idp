require 'rails_helper'

RSpec.describe 'idv/by_mail/request_letter/index.html.erb' do
  let(:user) { build(:user) }
  let(:go_back_path) { nil }
  let(:step_indicator_steps) { Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS }
  let(:idv_by_mail_only) { false }

  let(:address1) { 'applicant address 1' }
  let(:address2) { nil }
  let(:city) { 'applicant city' }
  let(:state) { 'applicant state' }
  let(:zipcode) { 'applicant zipcode' }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:go_back_path).and_return(go_back_path)
    allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)
    allow(FeatureManagement).to receive(:idv_by_mail_only?).and_return(idv_by_mail_only)

    @applicant = {
      address1: 'applicant address 1',
      city: 'applicant city',
      state: 'applicant state',
      zipcode: 'applicant zipcode',
    }
    if address2
      @applicant[:address2] = 'applicant address 2'
    end
    render
  end

  it 'prompts to send letter' do
    expect(rendered).to have_content(I18n.t('idv.titles.mail.verify'))
    expect(rendered).to have_button(I18n.t('idv.buttons.mail.send'))
  end

  it 'renders fallback link to return to phone verify path' do
    expect(rendered).to have_link('‹ ' + t('forms.buttons.back'), href: idv_phone_path)
  end

  context 'has page to go back to' do
    let(:go_back_path) { idv_otp_verification_path }

    it 'renders back link to return to previous path' do
      expect(rendered).to have_link('‹ ' + t('forms.buttons.back'), href: go_back_path)
    end
  end

  it 'renders the address lines' do
    expect(rendered).to have_content('applicant address 1')
    expect(rendered).to have_content('applicant city, applicant state applicant zipcode')
  end

  context 'when there is an address2' do
    let(:address2) { 'applicant address 2' }

    it 'renders the address line' do
      expect(rendered).to have_content('applicant address 2')
    end
  end

  context 'idv_by_mail_only is enabled' do
    let(:idv_by_mail_only) { true }

    it 'returns a cancel link' do
      expect(rendered).to have_link(t('links.cancel'), href: idv_cancel_path(step: 'gpo'))
    end
  end
end
