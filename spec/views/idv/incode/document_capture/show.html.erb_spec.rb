require 'rails_helper'

RSpec.describe 'idv/incode/document_capture/show.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:document_capture_session_uuid) { 'dcs-uuid-1234' }
  let(:user_uuid) { 'user-uuid-5678' }
  let(:incode_api_key) { 'test-api-key' }
  let(:incode_api_url) { 'https://demo-api.incodesmile.com' }
  let(:incode_sdk_url) { 'https://sdk.incodesmile.com/incode-web-sdk.min.js' }
  let(:incode_flow_id) { 'flow-123' }
  let(:update_url) { 'https://example.com/verify/incode/document_capture_update' }

  subject(:render_template) do
    render template: 'idv/incode/document_capture/show', locals: {
      document_capture_session_uuid:,
      user_uuid:,
      incode_api_key:,
      incode_api_url:,
      incode_sdk_url:,
      incode_flow_id:,
      update_url:,
    }
  end

  it 'renders the Incode document capture container with session data attributes' do
    render_template

    expect(rendered).to have_css(
      "#incode-document-capture[data-external-id='#{document_capture_session_uuid}']",
    )
    expect(rendered).to have_css(
      "#incode-document-capture[data-external-customer-id='#{user_uuid}']",
    )
    expect(rendered).to have_css(
      "#incode-document-capture[data-api-key='#{incode_api_key}']",
    )
    expect(rendered).to have_css(
      "#incode-document-capture[data-api-url='#{incode_api_url}']",
    )
    expect(rendered).to have_css(
      "#incode-document-capture[data-flow-id='#{incode_flow_id}']",
    )
    expect(rendered).to have_css(
      "#incode-document-capture[data-update-url='#{update_url}']",
    )
    expect(rendered).to have_css('#incode-camera-container.full-screen.bg-white')
  end
end
