# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'idv/shared/choose_id_type.html.erb' do
  include Devise::Test::ControllerHelpers
  let(:presenter) { Idv::ChooseIdTypePresenter.new }
  let(:form_submit_url) { '/idv/choose_id_type' }
  let(:disable_passports) { false }
  let(:passport_cards_enabled) { false }
  let(:mdl_enabled) { true }
  let(:disable_mdl) { false }
  let(:auto_check_value) { :mobile_drivers_license }
  let(:show_verify_in_person) { false }
  let(:nds_layout) { false }

  let(:locals) do
    {
      presenter:,
      form_submit_url:,
      disable_passports:,
      passport_cards_enabled:,
      mdl_enabled:,
      disable_mdl:,
      auto_check_value:,
      show_verify_in_person:,
    }
  end

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
  end

  subject(:rendered) do
    render template: 'idv/shared/choose_id_type', locals: locals
  end

  context 'standard layout' do
    it 'renders the form with available id options' do
      expect(rendered).to have_css('input[type=radio][value=state_id_card]')
      expect(rendered).to have_css('input[type=radio][value=passport]')
      expect(rendered).to have_css(
        'input[type=radio][value=mobile_drivers_license]:not([disabled])',
      )
    end

    context 'when mdl is disabled (e.g. after undetected mDL redirect)' do
      let(:mdl_enabled) { false }
      let(:disable_mdl) { true }
      let(:auto_check_value) { :state_id_card }

      it 'renders the mdl option disabled' do
        expect(rendered).to have_css(
          'input[type=radio][value=mobile_drivers_license][disabled]',
        )
      end

      it 'pre-checks the state_id_card option' do
        expect(rendered).to have_css(
          'input[type=radio][value=state_id_card][checked]',
        )
      end
    end
  end

  context 'NDS layout' do
    let(:nds_layout) { true }

    it 'renders the NDS form with available id options' do
      expect(rendered).to have_css('input[type=radio][value=state_id_card]')
      expect(rendered).to have_css('input[type=radio][value=passport]')
      expect(rendered).to have_css(
        'input[type=radio][value=mobile_drivers_license]:not([disabled])',
      )
    end

    context 'when mdl is disabled (e.g. after undetected mDL redirect)' do
      let(:mdl_enabled) { false }
      let(:disable_mdl) { true }
      let(:auto_check_value) { :state_id_card }

      it 'renders the mdl option disabled' do
        expect(rendered).to have_css(
          'input[type=radio][value=mobile_drivers_license][disabled]',
        )
      end

      it 'pre-checks the state_id_card option' do
        expect(rendered).to have_css(
          'input[type=radio][value=state_id_card][checked]',
        )
      end
    end
  end
end
