require 'rails_helper'

RSpec.describe 'idv/shared/_error.html.erb' do
  let(:sp_name) { nil }
  let(:options) { [{ text: 'Example', url: '#example' }] }
  let(:heading) { 'Error' }
  let(:action) { nil }
  let(:secondary_action) { nil }
  let(:type) { nil }
  let(:current_step) { nil }
  let(:step_indicator_steps) { nil }
  let(:params) do
    {
      type: type,
      heading: heading,
      action: action,
      secondary_action: secondary_action,
      current_step: current_step,
      options: options,
    }
  end

  let(:nds_layout) { false }

  before do
    decorated_sp_session = instance_double(ServiceProviderSession, sp_name: sp_name)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
    allow(view).to receive(:nds_layout?).and_return(nds_layout)

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
      let(:secondary_action) { { text: 'Secondary Action', url: '#secondary' } }

      it 'renders secondary action button' do
        expect(rendered).to have_link('Secondary Action', href: '#secondary')
      end
    end

    context 'with form action' do
      let(:secondary_action) { { text: 'Delete', url: '#delete', method: :delete } }

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
      let(:params) { { heading: heading } }

      it 'sets title as defaulting to heading' do
        expect(view).to receive(:title=).with(heading)

        render 'idv/shared/error', **params
      end
    end

    context 'with title' do
      let(:title) { 'Example Title' }
      let(:params) { { heading: heading, title: title } }

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
        expect(rendered).not_to have_css('.nds-troubleshooting-options')
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
      let(:params) { { heading: heading } }

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
      let(:current_step) { :verify_phone }

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
            text: t('step_indicator.flows.idv.verify_phone'),
          )
        end
      end
    end
  end

  it 'does not render the NDS form-page card in the default layout' do
    expect(rendered).not_to have_css('.auth--form-page')
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the form-page card with the heading' do
      expect(rendered).to have_css('section.auth.auth--form-page h1', text: heading)
    end

    it 'omits the divider when there is no body content' do
      expect(rendered).not_to have_css('.auth__form-page-body hr.divider')
    end

    context 'with whitespace-only body content' do
      before { render('idv/shared/error', **params) { '<p> </p>'.html_safe } }

      it 'omits the divider' do
        expect(rendered).not_to have_css('.auth__form-page-body hr.divider')
      end
    end

    context 'with body content' do
      before { render('idv/shared/error', **params) { 'Body copy' } }

      it 'renders a divider under the heading' do
        expect(rendered).to have_css('.auth__form-page-body hr.divider')
      end
    end

    describe 'type' do
      context 'absent' do
        let(:params) { { heading: heading } }

        it 'renders the error status-icon badge' do
          expect(rendered).to have_css(
            '.auth__header--with-media .nds-status-icon--error .usa-icon',
          )
        end
      end

      context 'warning' do
        let(:type) { :warning }

        it 'renders the warning status-icon badge' do
          expect(rendered).to have_css('.nds-status-icon--warning .usa-icon')
        end

        it 'shows the default troubleshooting heading' do
          expect(rendered).to have_css(
            '.auth__actions h2',
            text: t('components.troubleshooting_options.default_heading'),
          )
        end
      end

      context 'error' do
        let(:type) { :error }

        it 'shows the need-assistance troubleshooting heading' do
          expect(rendered).to have_css(
            '.auth__actions h2',
            text: t('idv.troubleshooting.headings.need_assistance'),
          )
        end
      end
    end

    describe 'action' do
      context 'without action' do
        it 'does not render a primary button' do
          expect(rendered).not_to have_css('.auth__actions .usa-button:not(.usa-button--tertiary)')
        end
      end

      context 'with action' do
        let(:action) { { text: 'Primary Action', url: '#primary' } }

        it 'renders the primary action in the actions stack' do
          expect(rendered).to have_css('.auth__actions a.usa-button', text: 'Primary Action')
          expect(rendered).to have_link('Primary Action', href: '#primary')
        end
      end

      context 'with a destructive variant' do
        let(:action) { { text: 'Cancel', url: '#cancel', variant: :destructive } }

        it 'renders the primary action with the requested variant' do
          expect(rendered).to have_css('.auth__actions a.usa-button--danger', text: 'Cancel')
        end
      end

      context 'with form action' do
        let(:action) { { text: 'Delete', url: '#delete', method: :delete } }

        it 'renders a form-submitting button' do
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
        it 'does not render a secondary button' do
          expect(rendered).not_to have_css('.usa-button--secondary')
        end
      end

      context 'with secondary action' do
        let(:secondary_action) { { text: 'Secondary Action', url: '#secondary' } }
        let(:params) do
          super().merge(
            secondary_action_heading: 'Other ways',
            secondary_action_text: 'You can also do this.',
          )
        end

        it 'renders the secondary button with its heading and text in the body' do
          expect(rendered).to have_css('a.usa-button--secondary', text: 'Secondary Action')
          expect(rendered).to have_css('.auth__form-page-body h2', text: 'Other ways')
          expect(rendered).to have_css('.auth__form-page-body p', text: 'You can also do this.')
        end
      end
    end

    describe 'options' do
      context 'no options' do
        let(:options) { [] }

        it 'does not render troubleshooting options' do
          expect(rendered).not_to have_css('.nds-troubleshooting-options')
        end
      end

      context 'with a promoted option' do
        let(:options) { [{ text: 'Status', url: '#status', variant: :secondary }] }

        it 'renders it with the requested variant' do
          expect(rendered).to have_css(
            '.nds-troubleshooting-options a.usa-button--secondary',
            text: 'Status',
          )
        end
      end

      context 'with options' do
        let(:options) { [{ text: 'Example', url: '#example', new_tab: true }] }

        it 'renders each option as a tertiary new-tab button' do
          expect(rendered).to have_css(
            '.nds-troubleshooting-options a.usa-button--tertiary[target=_blank][href="#example"]',
            text: 'Example',
          )
          expect(rendered).to have_css(
            '.nds-troubleshooting-options .usa-sr-only',
            text: t('links.new_tab'),
          )
        end
      end
    end

    describe 'current_step' do
      it 'does not render header progress by default' do
        expect(view.content_for(:nds_header_progress)).to be_nil
      end

      context 'current_step provided with steps available' do
        let(:current_step) { :verify_info }
        let(:step_indicator_steps) { Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS }

        it 'renders the verification header progress at the matching substep' do
          progress = view.content_for(:nds_header_progress)
          expect(progress).to have_css('nds-progress .progress__step[aria-current="step"]')
          expect(progress).to have_css('.progress__step-counter', text: '3 / 12')
        end

        it 'does not render the legacy step indicator' do
          expect(view.content_for(:pre_flash_content)).to be_nil
        end
      end
    end
  end
end
