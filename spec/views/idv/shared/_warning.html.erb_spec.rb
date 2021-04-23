require 'rails_helper'

describe 'idv/shared/_warning.html.erb' do
  let(:sp_name) { nil }
  let(:options) { nil }
  let(:heading) { 'Warning' }
  let(:action) { nil }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator, sp_name: sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)

    render 'idv/shared/warning', heading: heading, action: action, options: options
  end

  it 'renders heading' do
    expect(rendered).to have_css('h1', text: heading)
  end

  context 'without an SP' do
    it 'renders a list of troubleshooting options' do
      expect(rendered).not_to have_link(href: return_to_sp_cancel_path)
    end
  end

  context 'with an SP' do
    let(:sp_name) { 'Example SP' }

    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        href: return_to_sp_failure_to_proof_path,
      )
    end
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

  describe 'options' do
    context 'without options customization' do
      it 'does not render troubleshooting options' do
        expect(rendered).not_to have_css('.troubleshooting-options')
      end
    end

    context 'with options customization' do
      let(:options) { Proc.new { |options| options.append(text: 'Example', url: '#example') } }

      it 'renders a list of troubleshooting options' do
        expect(rendered).to have_link('Example', href: '#example')
      end
    end
  end
end
