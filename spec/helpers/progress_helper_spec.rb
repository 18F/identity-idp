# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProgressHelper do
  describe '#ads_progress' do
    let(:user_session) { {} }

    before do
      without_partial_double_verification do
        allow(helper).to receive(:controller_path).and_return(controller_path)
        allow(helper).to receive(:action_name).and_return(action_name)
        allow(helper).to receive(:user_session).and_return(user_session)
      end
    end

    context 'on an early create-account screen' do
      let(:controller_path) { 'sign_up/registrations' }
      let(:action_name) { 'new' }

      it 'returns a progress component at step 0' do
        component = helper.ads_progress

        expect(component).to be_a(ProgressComponent)
        expect(component.current_step).to eq(0)
        expect(component.current_substep).to eq(1)
        expect(component.substep_count).to eq(2)
        expect(component.steps).to eq(
          [
            t('step_indicator.flows.sign_up.create_account'),
            t('step_indicator.flows.sign_up.secure'),
            t('step_indicator.flows.sign_up.connect'),
          ],
        )
      end

      it 'matches create re-render action to the same position' do
        without_partial_double_verification do
          allow(helper).to receive(:action_name).and_return('create')
        end

        expect(helper.ads_progress.current_step).to eq(0)
        expect(helper.ads_progress.current_substep).to eq(1)
      end
    end

    context 'on an MFA setup screen' do
      let(:controller_path) { 'users/two_factor_authentication_setup' }
      let(:action_name) { 'index' }

      context 'outside account creation' do
        it 'hides progress' do
          expect(helper.ads_progress).to be_nil
        end
      end

      context 'during account creation' do
        let(:user_session) { { in_account_creation_flow: true } }

        it 'shows authentication step progress' do
          component = helper.ads_progress

          expect(component.current_step).to eq(1)
          expect(component.current_substep).to eq(1)
          expect(component.substep_count).to eq(2)
        end
      end

      context 'during multi-MFA selection without creation' do
        let(:user_session) do
          { mfa_selections: %w[phone backup_code], mfa_selection_index: 0 }
        end

        it 'hides progress (account-management MFA)' do
          expect(helper.ads_progress).to be_nil
        end
      end

      context 'during multi-MFA selection with creation' do
        let(:user_session) do
          {
            in_account_creation_flow: true,
            mfa_selections: %w[phone backup_code],
            mfa_selection_index: 0,
          }
        end

        it 'shows progress' do
          expect(helper.ads_progress).to be_a(ProgressComponent)
        end
      end
    end

    context 'on an unmapped screen' do
      let(:controller_path) { 'users/sessions' }
      let(:action_name) { 'new' }

      it 'returns nil' do
        expect(helper.ads_progress).to be_nil
      end
    end

    context 'when the page opts out' do
      let(:controller_path) { 'sign_up/registrations' }
      let(:action_name) { 'new' }

      it 'returns nil' do
        helper.content_for(:hide_ads_progress, '1')

        expect(helper.ads_progress).to be_nil
      end
    end

    context 'when IDV already assigned a progress component' do
      let(:controller_path) { 'sign_up/registrations' }
      let(:action_name) { 'new' }

      it 'prefers the IDV component over the route map' do
        idv = ProgressComponent.new(steps: ['Getting started'], current_step: 0)
        helper.instance_variable_set(:@ads_progress_component, idv)

        expect(helper.ads_progress).to equal(idv)
      end
    end
  end

  describe '#ads_chrome_progress' do
    let(:user_session) { { in_account_creation_flow: true } }

    before do
      without_partial_double_verification do
        allow(helper).to receive(:controller_path).and_return('users/phone_setup')
        allow(helper).to receive(:action_name).and_return('index')
        allow(helper).to receive(:user_session).and_return(user_session)
      end
    end

    it 'returns HTML for a route-mapped component' do
      html = helper.ads_chrome_progress

      expect(html).to be_present
      expect(html).to include('ads-progress')
      expect(html).to include(t('step_indicator.flows.sign_up.secure'))
    end

    it 'returns HTML for an IDV-assigned component' do
      helper.instance_variable_set(
        :@ads_progress_component,
        ProgressComponent.new(steps: ['Getting started', 'Verify ID'], current_step: 0),
      )

      html = helper.ads_chrome_progress

      expect(html).to include('Getting started')
      expect(html).to include('ads-progress')
    end

    it 'respects hide opt-out' do
      helper.content_for(:hide_ads_progress, '1')

      expect(helper.ads_chrome_progress).to be_nil
    end
  end
end
