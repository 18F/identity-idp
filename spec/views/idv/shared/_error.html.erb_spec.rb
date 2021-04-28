require 'rails_helper'

describe 'idv/shared/_error.html.erb' do
  let(:sp_name) { nil }
  let(:options) { [{ text: 'Example', url: '#example' }] }
  let(:heading) { 'Error' }
  let(:action) { nil }
  let(:type) { nil }
  let(:params) { { type: type, heading: heading, action: action, options: options } }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator, sp_name: sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)
    allow(view).to receive(:title)

    render 'idv/shared/error', **params
  end

  it 'renders heading' do
    expect(rendered).to have_css('h1', text: heading)
  end

  describe 'action' do
    context 'without action' do
      it 'does not render action button' do
        expect(rendered).not_to have_css('.usa-button')
      end
    end

    context 'with action' do
      let(:action) { { text: 'Example', url: '#example' } }

      it 'renders action button' do
        expect(rendered).to have_link('Example', href: '#example')
      end
    end
  end

  describe 'title' do
    context 'without title' do
      let(:params) { { heading: heading } }

      it 'sets title as defaulting to heading' do
        expect(view).to receive(:title).with(heading)

        render 'idv/shared/error', **params
      end
    end

    context 'with title' do
      let(:title) { 'Example Title' }
      let(:params) { { heading: heading, title: title } }

      it 'sets title' do
        expect(view).to receive(:title).with(title)

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
      let(:options) { [{text: 'Example', url: '#example'}] }

      it 'renders a list of troubleshooting options' do
        expect(rendered).to have_link('Example', href: '#example')
      end
    end
  end

  describe 'type' do
    context 'absent' do
      let(:params) { { heading: heading } }

      it 'defaults to error' do
        expect(rendered).to have_css('[src*="fail-x"]')
      end
    end

    context 'warning' do
      let(:type) { :warning }

      it 'includes decorative image' do
        expect(rendered).to have_css('[src*="warning-lg"][alt=""]')
      end

      it 'shows an appropriate troubleshooting heading' do
        expect(rendered).to have_css('h2', text: t('idv.troubleshooting.headings.having_trouble'))
      end
    end

    context 'error' do
      let(:type) { :error }

      it 'includes decorative image' do
        expect(rendered).to have_css('[src*="fail-x"][alt=""]')
      end

      it 'shows an appropriate troubleshooting heading' do
        expect(rendered).to have_css('h2', text: t('idv.troubleshooting.headings.need_assistance'))
      end
    end
  end
end
