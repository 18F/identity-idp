require 'rails_helper'

describe 'idv/shared/_ssn.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:proofing_device_profiling_collecting_enabled) { nil }
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

    allow(IdentityConfig.store).
      to receive(:proofing_device_profiling_collecting_enabled).
      and_return(proofing_device_profiling_collecting_enabled)
    allow(IdentityConfig.store).
      to receive(:lexisnexis_threatmetrix_org_id).and_return(lexisnexis_threatmetrix_org_id)

    render partial: 'idv/shared/ssn', locals: {
      flow_session: {},
      success_alert_enabled: false,
      threatmetrix_session_id: session_id,
      updating_ssn: updating_ssn,
    }
  end

  context 'when threatmetrix collection enabled' do
    let(:proofing_device_profiling_collecting_enabled) { true }

    context 'and org id specified' do
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

    context 'org id not specified' do
      let(:lexisnexis_threatmetrix_org_id) { '' }

      it 'does not render <script> tag' do
        expect_script_tag_not_rendered
      end
      it 'does not render <noscript> tag' do
        expect_noscript_tag_not_rendered
      end
    end
  end

  context 'threatmetrix collection disabled' do
    let(:proofing_device_profiling_collecting_enabled) { false }

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
