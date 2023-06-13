module BrowserEmulationHelper
  def emulate_reduced_motion
    # See: https://chromedevtools.github.io/devtools-protocol/tot/Emulation/#method-setEmulatedMedia
    send_bridge_command(
      'Emulation.setEmulatedMedia',
      features: [{ name: 'prefers-reduced-motion', value: 'reduce' }],
    )
  end

  def send_bridge_command(command, params)
    bridge = Capybara.current_session.driver.browser.send(:bridge)
    path = "/session/#{bridge.session_id}/chromium/send_command"
    bridge.http.call(:post, path, cmd: command, params:)
  end
end
