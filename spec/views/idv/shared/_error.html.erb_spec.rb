require 'rails_helper'

RSpec.describe 'idv/shared/_error.html.erb' do
  let(:sp_name) { nil }
  let(:options) { [] }
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

  before do
    decorated_sp_session = instance_double(ServiceProviderSession, sp_name: sp_name)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)

    if step_indicator_steps
      allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)
    end

    render('idv/shared/error', **params) { 'Alert body' }
  end

  it 'renders heading' do
    expect(rendered).to have_css('h1', text: heading)
  end

  describe 'action' do
    context 'without action' do
      it 'does not render action button' do
        expect(rendered).not_to have_css('.ads-auth__actions')
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
        expect(rendered).to have_css('.ads-auth__actions a', count: 1)
      end
    end

    context 'with secondary action' do
      let(:secondary_action) { { text: 'Secondary Action', url: '#secondary' } }

      it 'renders secondary action button in the actions group' do
        expect(rendered).to have_css('.ads-auth__actions a', text: 'Primary Action')
        expect(rendered).to have_css('.ads-auth__actions a', text: 'Secondary Action')
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

        render('idv/shared/error', **params) { 'Alert body' }
      end
    end

    context 'with title' do
      let(:title) { 'Example Title' }
      let(:params) { { heading: heading, title: title } }

      it 'sets title' do
        expect(view).to receive(:title=).with(title)

        render('idv/shared/error', **params) { 'Alert body' }
      end
    end
  end

  describe 'options' do
    let(:options) { [{ text: 'Example', url: '#example' }] }
    let(:action) { { text: 'Try again', url: '#retry' } }

    context 'on warning' do
      let(:type) { :warning }

      it 'renders troubleshooting below the primary action as body copy' do
        expect(rendered).to have_css(
          '.ads-auth__actions .ads-idv-support__troubleshooting p',
          text: t('components.troubleshooting_options.default_heading'),
        )
        expect(rendered).to have_css(
          '.ads-auth__actions a[href="#retry"] ~ .ads-idv-support__troubleshooting',
        )
        expect(rendered).to have_link('Example', href: '#example')
      end
    end

    context 'on error' do
      let(:type) { :error }

      it 'does not render troubleshooting options' do
        expect(rendered).not_to have_css('.ads-idv-support__troubleshooting')
        expect(rendered).not_to have_link('Example', href: '#example')
      end
    end
  end

  describe 'type' do
    context 'absent' do
      let(:params) { { heading: heading } }

      it 'defaults to error alert' do
        expect(rendered).to have_css('.ads-alert--error')
      end
    end

    context 'warning' do
      let(:type) { :warning }

      it 'renders a warning alert' do
        expect(rendered).to have_css('.ads-alert--warning')
      end
    end

    context 'error' do
      let(:type) { :error }

      it 'renders an error alert' do
        expect(rendered).to have_css('.ads-alert--error')
      end
    end
  end

  describe 'current_step' do
    it 'does not render a step indicator by default' do
      expect(view.content_for?(:pre_flash_content)).to eq(false)
    end

    context 'current_step provided' do
      let(:current_step) { :verify_phone }

      it 'does not render a step indicator' do
        expect(view.content_for?(:pre_flash_content)).to eq(false)
      end
    end
  end
end
