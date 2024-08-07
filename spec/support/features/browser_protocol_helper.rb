module BrowserProtocolHelper
  def emulate_reduced_motion
    # See: https://chromedevtools.github.io/devtools-protocol/tot/Emulation/#method-setEmulatedMedia
    send_bridge_command(
      'Emulation.setEmulatedMedia',
      features: [{ name: 'prefers-reduced-motion', value: 'reduce' }],
    )
  end

  def accessibility_tree(element)
    send_bridge_command('Accessibility.enable')
    send_bridge_command(
      'Accessibility.getPartialAXTree',
      backendNodeId: node_id(element),
      fetchRelatives: false,
    )['value']['nodes'].first
  end

  def node_id(element)
    # Selenium internally tracks the ID for an element, and exposes it on a `ref` method tuple as
    # the second member. The Selenium ID includes the Chromium node ID as the last portion of a
    # dot-delimited string.
    #
    # Example `ref`:
    # [:element, "f.EEC554C38DC5E6172B08F9C59A572EEA.d.6CDD556B3BF6E9A7FDAEA1F6CBD9EDF2.e.77"]
    #
    # In the example above, the Chromium node ID is `77`.
    #
    # See: https://github.com/SeleniumHQ/selenium/blob/trunk/rb/lib/selenium/webdriver/common/element.rb
    element.native.ref[1].split('.').last.to_i
  end

  def send_bridge_command(command, params = {})
    bridge = Capybara.current_session.driver.browser.send(:bridge)
    # See: https://github.com/SeleniumHQ/selenium/blob/trunk/rb/lib/selenium/webdriver/chrome/features.rb
    path = "/session/#{bridge.session_id}/goog/cdp/execute"
    bridge.http.call(:post, path, cmd: command, params:)
  end
end
