require 'rails_helper'

RSpec.describe 'idv/address/new' do
  let(:user) { build(:user) }
  let(:parsed_page) { Nokogiri::HTML.parse(rendered) }
  let(:gpo_request_letter_visited) { nil }
  let(:address_update_request) { nil }
  let(:step_indicator_steps) { Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS }

  shared_examples 'valid address page and form' do
    before do
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)
      assign(
        :presenter, Idv::AddressPresenter.new(
          gpo_request_letter_visited: gpo_request_letter_visited,
          address_update_request: address_update_request,
        )
      )
      assign(:address_form, Idv::AddressForm.new({}))
      render
    end

    it 'has correct address content' do
      if gpo_request_letter_visited
        expect(parsed_page).to have_content(t('doc_auth.headings.mailing_address'))
        expect(parsed_page).to have_content(t('doc_auth.info.mailing_address'))
        expect(parsed_page).to have_content(t('forms.buttons.continue'))
        expect(parsed_page).to have_link(t('forms.buttons.back'), href: idv_request_letter_path)
      elsif address_update_request
        expect(parsed_page).to have_content(t('doc_auth.headings.address_update'))
        expect(parsed_page).to have_content(t('doc_auth.info.address'))
        expect(parsed_page).to have_content(t('forms.buttons.submit.update'))
        expect(parsed_page).to have_link(t('forms.buttons.back'), href: idv_verify_info_path)
      else
        expect(parsed_page).to have_content(t('doc_auth.headings.address'))
        expect(parsed_page).to have_content(t('doc_auth.info.address'))
        expect(parsed_page).to have_content(t('forms.buttons.continue'))
        expect(parsed_page).to have_link(t('links.cancel'))
      end
    end

    describe 'the Puerto Rico guidance text' do
      let(:guidance) { parsed_page.at_css('div#puerto-rico-extra-text') }
      let(:expected_text) { t('doc_auth.info.address_guidance_puerto_rico_html').gsub('<br>', '') }

      it 'has the correct text' do
        expect(guidance.text).to match(/#{expected_text}/)
      end

      it 'is hidden' do
        expect(guidance.classes).to include('display-none')
      end
    end

    describe 'the Puerto Rico address1 blurb' do
      let(:hint) do
        parsed_page.at_css('input#idv_form_address1').parent.at_css('.usa-hint')
      end

      it 'has the correct text' do
        expected_text = "#{t('forms.example')} 150 Calle A Apt 3"

        expect(hint.text).to match(/#{expected_text}/)
      end

      it 'is hidden' do
        expect(hint.classes).to include('display-none')
      end
    end

    describe 'the Puerto Rico address2 blurb' do
      let(:hint) do
        parsed_page.at_css('input#idv_form_address2').parent.at_css('.usa-hint')
      end

      it 'has the correct text' do
        expected_text = "#{t('forms.example')} URB Las Gladiolas"

        expect(hint.text).to match(/#{expected_text}/)
      end

      it 'is hidden' do
        expect(hint.classes).to include('display-none')
      end
    end

    describe 'the Puerto Rico city blurb' do
      let(:hint) do
        parsed_page.at_css('input#idv_form_city').parent.at_css('.usa-hint')
      end

      it 'has the correct text' do
        expected_text = "#{t('forms.example')} San Juan"

        expect(hint.text).to match(/#{expected_text}/)
      end

      it 'is hidden' do
        expect(hint.classes).to include('display-none')
      end
    end

    describe 'the Puerto Rico zipcode blurb' do
      let(:hint) do
        parsed_page.at_css('input#idv_form_zipcode').parent.at_css('.usa-hint')
      end

      it 'has the correct text' do
        expected_text = "#{t('forms.example')} 00926"

        expect(hint.text).to match(/#{expected_text}/)
      end

      it 'is hidden' do
        expect(hint.classes).to include('display-none')
      end
    end
  end

  context 'when user is not requesting an update' do
    it_behaves_like 'valid address page and form'
  end
  context 'when the user is requesting a GPO letter' do
    let(:gpo_request_letter_visited) { true }

    it_behaves_like 'valid address page and form'
  end

  context 'whene user is requesting an address update' do
    let(:address_update_request) { true }

    it_behaves_like 'valid address page and form'
  end
end
