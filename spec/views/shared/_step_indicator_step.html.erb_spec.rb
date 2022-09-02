require 'rails_helper'

describe 'shared/_step_indicator_step.html.erb' do
  context 'without block content' do
    it 'raises an error if no block given' do
      expect { render 'shared/step_indicator_step' }.to raise_error('no block content given')
    end
  end

  context 'with block content' do
    let(:title) { 'Step Name' }
    let(:status) { nil }

    before do
      render('shared/step_indicator_step', status: status) { title }
    end

    it 'renders step title' do
      expect(rendered).to have_content(title)
    end

    describe 'status' do
      context 'with nil status' do
        it 'renders incomplete step' do
          expect(rendered).to have_selector('.step-indicator__step')
          expect(rendered).not_to have_selector('.step-indicator__step--current')
          expect(rendered).not_to have_selector('.step-indicator__step--complete')
        end

        it 'renders accessible indicator' do
          expect(rendered).to have_text(t('step_indicator.status.not_complete'))
        end
      end

      context 'with current status' do
        let(:status) { :current }

        it 'renders current step' do
          expect(rendered).to have_selector('.step-indicator__step')
          expect(rendered).to have_selector('.step-indicator__step--current')
          expect(rendered).not_to have_selector('.step-indicator__step--complete')
        end

        it 'renders accessible indicator' do
          expect(rendered).to have_text(t('step_indicator.status.current'))
        end
      end

      context 'with pending status' do
        let(:status) { :pending }

        it 'renders pending step' do
          expect(rendered).to have_selector('.step-indicator__step')
          expect(rendered).not_to have_selector('.step-indicator__step--current')
          expect(rendered).not_to have_selector('.step-indicator__step--complete')
        end

        it 'renders visible pending indicator' do
          expect(rendered).to have_text(t('step_indicator.status.pending'))
        end
      end

      context 'with complete status' do
        let(:status) { :complete }

        it 'renders complete step' do
          expect(rendered).to have_selector('.step-indicator__step')
          expect(rendered).to have_selector('.step-indicator__step--complete')
          expect(rendered).not_to have_selector('.step-indicator__step--current')
        end

        it 'renders accessible indicator' do
          expect(rendered).to have_text(t('step_indicator.status.complete'))
        end
      end
    end
  end
end
