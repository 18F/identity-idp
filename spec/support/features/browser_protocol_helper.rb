module BrowserProtocolHelper
  def emulate_reduced_motion
    # See: https://chromedevtools.github.io/devtools-protocol/tot/Emulation/#method-setEmulatedMedia
    send_bridge_command(
      'Emulation.setEmulatedMedia',
      features: [{ name: 'prefers-reduced-motion', value: 'reduce' }],
    )
  end

  def accessibility_tree(element)
    # See: https://github.com/SeleniumHQ/selenium/blob/trunk/rb/lib/selenium/webdriver/common/element.rb
    node_id = element.native.ref[1].split('.').last.to_i
    send_bridge_command('Accessibility.enable')
    ax_tree_response = send_bridge_command(
      'Accessibility.getPartialAXTree',
      backendNodeId: node_id,
      fetchRelatives: false,
    )
    ax_tree_response['value']['nodes'].first
  end

  def send_bridge_command(command, params = {})
    bridge = Capybara.current_session.driver.browser.send(:bridge)
    # See: https://github.com/SeleniumHQ/selenium/blob/trunk/rb/lib/selenium/webdriver/chrome/features.rb
    path = "/session/#{bridge.session_id}/goog/cdp/execute"
    bridge.http.call(:post, path, cmd: command, params:)
  end
end
