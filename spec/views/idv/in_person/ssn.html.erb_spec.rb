require 'rails_helper'

RSpec.describe 'idv/in_person/ssn.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:threatmetrix_enabled) { nil }
  let(:lexisnexis_threatmetrix_org_id) { 'test_org_id' }
  let(:session_id) { 'ABCD-1234' }
  let(:updating_ssn) { false }
  let(:js_domain) { 'h.online-metrix.net' }

  let(:tags_js_url) do
    "https://#{js_domain}/fp/tags.js?org_id=#{lexisnexis_threatmetrix_org_id}&session_id=#{session_id}"
  end

  let(:tags_iframe_url) do
    "https://#{js_domain}/fp/tags?org_id=#{lexisnexis_threatmetrix_org_id}&session_id=#{session_id}"
  end

  before :each do
    allow(view).to receive(:url_for).and_return('https://example.com/')

    allow(IdentityConfig.store).to receive(:proofing_device_profiling).
      and_return(threatmetrix_enabled ? :enabled : :disabled)
    allow(IdentityConfig.store).
      to receive(:lexisnexis_threatmetrix_org_id).and_return(lexisnexis_threatmetrix_org_id)

    render template: 'idv/in_person/ssn', locals: {
      flow_session: {},
      threatmetrix_session_id: session_id,
      updating_ssn: updating_ssn,
      threatmetrix_javascript_urls: [tags_js_url],
      threatmetrix_iframe_url: tags_iframe_url,
    }
  end

  context 'when threatmetrix collection enabled' do
    let(:threatmetrix_enabled) { true }

    context 'and entering ssn for the first time' do
      describe '<script> tag' do
        it 'is rendered' do
          expect_script_tag_rendered
        end
      end

      describe '<noscript> tag' do
        it 'is rendered' do
          expect_noscript_tag_rendered
        end
      end

      context 'session id not specified' do
        let(:session_id) { nil }

        it 'does not render <script> tag' do
          expect_script_tag_not_rendered
        end
        it 'does not render <noscript> tag' do
          expect_noscript_tag_not_rendered
        end
      end
    end
  end

  context 'threatmetrix collection disabled' do
    let(:threatmetrix_enabled) { false }

    it 'does not render <script> tag' do
      expect_script_tag_not_rendered
    end
    it 'does not render <noscript> tag' do
      expect_noscript_tag_not_rendered
    end
  end

  def expect_script_tag_rendered
    expect(rendered).to have_css("script[nonce][src='#{tags_js_url}']", visible: false)
  end

  def expect_noscript_tag_rendered
    expect(rendered).to have_css("noscript iframe[src='#{tags_iframe_url}']", visible: false)
  end

  def expect_session_id_input_rendered
    expect(rendered).
      to have_css(
        "input[type=hidden][name='doc_auth[threatmetrix_session_id]'][value='#{session_id}']",
        visible: false,
      )
  end

  def expect_script_tag_not_rendered
    expect(rendered).not_to have_css("script[src*='#{js_domain}']", visible: false)
  end

  def expect_noscript_tag_not_rendered
    expect(rendered).not_to have_css("noscript iframe[src*='#{js_domain}']", visible: false)
  end

  def expect_session_id_input_not_rendered
    expect(rendered).
      not_to have_css('input[name="doc_auth[threatmetrix_session_id]"]', visible: false)
  end
end
