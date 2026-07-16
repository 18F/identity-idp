require 'rails_helper'

RSpec.describe ADS::LinkComponent, type: :component do
  it 'renders block content as a semantic destination link' do
    rendered = render_inline(
      described_class.new(url: '/sign_up').with_content(
        '<span>Create <strong>an account</strong></span>'.html_safe,
      ),
    )

    link = rendered.at_css('a')

    expect(link['href']).to eq('/sign_up')
    expect(link.at_css('strong').text).to eq('an account')
  end

  it 'forwards Rails link options and accessible labeling' do
    rendered = render_inline(
      described_class.new(
        url: '/sign_up',
        target: '_blank',
        rel: 'noopener',
        aria: { label: 'Create a Login.gov account' },
        data: { turbo_method: :post },
      ).with_content('Create an account'),
    )

    link = rendered.at_css('a')

    expect(link['href']).to eq('/sign_up')
    expect(link['target']).to eq('_blank')
    expect(link['rel'].split).to include('noopener')
    expect(link['aria-label']).to eq('Create a Login.gov account')
    expect(link['data-turbo-method']).to eq('post')
  end
end
