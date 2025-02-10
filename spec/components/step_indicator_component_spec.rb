require 'rails_helper'

RSpec.describe StepIndicatorComponent, type: :component do
  let(:classes) { nil }
  let(:steps) { [{ name: :one }, { name: :two }, { name: :three }] }
  let(:current_step) { :one }
  let(:locale_scope) { 'example' }

  around do |example|
    original_backend = I18n.backend
    I18n.backend = I18n::Backend::Chain.new(
      I18n::Backend::KeyValue.new(Hash.new, true),
      original_backend,
    )
    I18n.backend.store_translations(
      :en,
      step_indicator: {
        flows: {
          example: {
            one: 'One',
            two: 'Two',
            three: 'Three',
          },
        },
      },
    )
    example.run
    I18n.backend = original_backend
  end

  subject(:rendered) do
    render_inline StepIndicatorComponent.new(
      steps:,
      current_step:,
      locale_scope:,
      class: classes,
    )
  end

  describe 'classes' do
    let(:classes) { nil }

    context 'without custom classes given' do
      let(:classes) { nil }

      it 'renders with default tag' do
        expect(rendered).to have_selector('lg-step-indicator')
      end
    end

    context 'with custom classes' do
      let(:classes) { 'my-custom-class' }

      it 'renders with additional custom classes' do
        expect(rendered).to have_selector('lg-step-indicator.my-custom-class')
      end
    end
  end

  describe 'steps' do
    it 'renders steps' do
      expect(rendered).to have_css(
        '.step-indicator__step',
        text: t('step_indicator.flows.example.one'),
      )
      expect(rendered).to have_css(
        '.step-indicator__step',
        text: t('step_indicator.flows.example.two'),
      )
      expect(rendered).to have_css(
        '.step-indicator__step',
        text: t('step_indicator.flows.example.three'),
      )
    end

    context 'explicit step status' do
      let(:steps) { [{ name: :one, status: :complete }, { name: :two }] }
      let(:current_step) { :two }

      it 'renders with status' do
        expect(rendered).to have_css(
          '.step-indicator__step--complete',
          text: t('step_indicator.flows.example.one'),
        )
      end
    end
  end

  describe 'current_step' do
    it 'renders current step' do
      expect(rendered).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.example.one'),
      )
    end

    context 'with complete step' do
      let(:current_step) { :two }

      it 'renders current step' do
        expect(rendered).to have_css(
          '.step-indicator__step--current',
          text: t('step_indicator.flows.example.two'),
        )
      end

      it 'renders completed step' do
        expect(rendered).to have_css(
          '.step-indicator__step--complete',
          text: t('step_indicator.flows.example.one'),
        )
        expect(rendered).to have_css(
          '.step-indicator__step--complete',
          text: t('step_indicator.status.complete'),
        )
      end
    end
  end

  describe 'locale_scope' do
    it 'translates using given scope' do
      expect(rendered).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.example.one'),
      )
    end

    context 'with nil scope' do
      let(:steps) { [{ name: :one, title: 'Nil Scope One' }] }
      let(:locale_scope) { nil }

      it 'uses title' do
        expect(rendered).to have_css(
          '.step-indicator__step--current',
          text: 'Nil Scope One',
        )
      end
    end
  end

  context 'with invalid step' do
    let(:current_step) { :missing }

    it 'renders without a current step' do
      expect(rendered).not_to have_css('.step-indicator__step--current')
    end
  end
end
