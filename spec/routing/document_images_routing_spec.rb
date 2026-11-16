require 'rails_helper'

RSpec.describe 'document image routes', type: :routing do
  it 'serves an image only on POST, which carries the client assertion in the body' do
    expect(post: '/api/openid_connect/document_images/front')
      .to route_to('openid_connect/document_images#show', image_type: 'front')
    expect(get: '/api/openid_connect/document_images/front').to route_to(
      'pages#page_not_found', path: 'api/openid_connect/document_images/front'
    )
  end
end
