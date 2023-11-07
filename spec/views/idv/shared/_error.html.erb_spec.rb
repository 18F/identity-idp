require 'rails_helper'

RSpec.describe 'idv/shared/_error.html.erb' do
  let(:sp_name) { nil }
  let(:options) { [{ text: 'Example', url: '#example' }] }
  let(:heading) { 'Error' }
  let(:action) { nil }
  let(:action_secondary) { nil }
  let(:type) { nil }
  let(:current_step) { nil }
  let(:step_indicator_steps) { nil }
  let(:params) do
    {
      type:,
      heading:,
      action:,
      action_secondary:,
      current_step:,
      options:,
    }
  end

  before do
    decorated_sp_session = instance_double(ServiceProviderSession, sp_name:)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)

    if step_indicator_steps
      allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)
    end

    render 'idv/shared/error', **params
  end

  it 'renders heading' do
    expect(rendered).to have_css('h1', text: heading)
  end

  describe 'action' do
    context 'without action' do
      it 'does not render action button' do
        expect(rendered).not_to have_css('.usa-button--primary')
      end
    end

    context 'with action' do
      let(:action) { { text: 'Primary Action', url: '#primary' } }

      it 'renders action button' do
        expect(rendered).to have_link('Primary Action', href: '#primary')
      end
    end

    context 'with form action' do
      let(:action) { { text: 'Delete', url: '#delete', method: :delete } }

      it 'renders action button' do
        expect(rendered).to have_button('Delete')
        expect(rendered).to have_css(
          'form[action="#delete"] input[name="_method"][value="delete"]',
          visible: :all,
        )
      end
    end
  end

  describe 'secondary action' do
    let(:action) { { text: 'Primary Action', url: '#primary' } }

    context 'without secondary action' do
      it 'does not render secondary action button' do
        expect(rendered).not_to have_css('.usa-button--outline')
      end
    end

    context 'with secondary action' do
      let(:action_secondary) { { text: 'Secondary Action', url: '#secondary' } }

      it 'renders secondary action button' do
        expect(rendered).to have_link('Secondary Action', href: '#secondary')
      end
    end

    context 'with form action' do
      let(:action_secondary) { { text: 'Delete', url: '#delete', method: :delete } }

      it 'renders action button' do
        expect(rendered).to have_button('Delete')
        expect(rendered).to have_css(
          'form[action="#delete"] input[name="_method"][value="delete"]',
          visible: :all,
        )
      end
    end
  end

  describe 'title' do
    context 'without title' do
      let(:params) { { heading: } }

      it 'sets title as defaulting to heading' do
        expect(view).to receive(:title=).with(heading)

        render 'idv/shared/error', **params
      end
    end

    context 'with title' do
      let(:title) { 'Example Title' }
      let(:params) { { heading:, title: } }

      it 'sets title' do
        expect(view).to receive(:title=).with(title)

        render 'idv/shared/error', **params
      end
    end
  end

  describe 'options' do
    context 'no options' do
      let(:options) { [] }

      it 'does not render troubleshooting options' do
        expect(rendered).not_to have_css('.troubleshooting-options')
      end
    end

    context 'with options' do
      let(:options) { [{ text: 'Example', url: '#example' }] }

      it 'renders a list of troubleshooting options' do
        expect(rendered).to have_link('Example', href: '#example')
      end
    end
  end

  describe 'type' do
    context 'absent' do
      let(:params) { { heading: } }

      it 'defaults to error' do
        expect(rendered).to have_css('[src*="error"]')
      end
    end

    context 'warning' do
      let(:type) { :warning }

      it 'includes informative image' do
        expect(rendered).to have_css("[src*='warning'][alt='#{t('image_description.warning')}']")
      end

      it 'shows an appropriate troubleshooting heading' do
        expect(rendered).to have_css(
          'h2',
          text: t('components.troubleshooting_options.default_heading'),
        )
      end
    end

    context 'error' do
      let(:type) { :error }

      it 'includes informative image' do
        expect(rendered).to have_css("[src*='error'][alt='#{t('image_description.error')}']")
      end

      it 'shows an appropriate troubleshooting heading' do
        expect(rendered).to have_css('h2', text: t('idv.troubleshooting.headings.need_assistance'))
      end
    end
  end

  describe 'current_step' do
    it 'does not render a step indicator by default' do
      expect(view.content_for(:pre_flash_content)).not_to have_css('lg-step-indicator')
    end

    context 'current_step provided' do
      let(:current_step) { :verify_phone_or_address }

      it 'does not render a step indicator' do
        expect(view.content_for(:pre_flash_content)).not_to have_css('lg-step-indicator')
      end

      context 'step_indicator_steps helper available' do
        let(:step_indicator_steps) { Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS }
        it 'renders a step indicator' do
          expect(view.content_for(:pre_flash_content)).to have_css('lg-step-indicator')
        end

        it 'selects the correct step' do
          expect(view.content_for(:pre_flash_content)).to have_css(
            '.step-indicator__step--current .step-indicator__step-title',
            text: t('step_indicator.flows.idv.verify_phone_or_address'),
          )
        end
      end
    end
  end
end
