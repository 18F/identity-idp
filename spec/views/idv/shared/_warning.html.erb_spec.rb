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
    let(:options) { [{text: 'Example', url: '#example'}] }

    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link('Example', href: '#example')
    end
  end
end
