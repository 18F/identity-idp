require 'socket'

class EnvIrbPrompt
  # @param [Hash] irb_conf
  def configure!(irb_conf = IRB.conf)
    irb_conf[:USE_AUTOCOMPLETE] = false
    irb_conf[:SAVE_HISTORY] = on_deployed_box? ? nil : 1000

    irb_conf[:PROMPT][:ENV_PROMPT] = {
      PROMPT_I: "%N(#{bold(env)}):%03n:%i> ",
      PROMPT_S: "%N(\e[1m#{bold(env)}\e[22m):%03n:%i%l ",
      PROMPT_C: "%N(\e[1m#{bold(env)}\e[22m):%03n:%i* ",
      RETURN: "%s\n",
    }
    irb_conf[:PROMPT_MODE] = :ENV_PROMPT
  end

  def on_deployed_box?
    return @on_deployed_box if defined?(@on_deployed_box)
    @on_deployed_box = File.directory?('/srv/idp/releases/')
  end

  def env
    if on_deployed_box?
      _host, env, _domain, _gov = Socket.gethostname.split('.')
      env
    else
      'local'
    end
  end

  # @api private
  def bold(str)
    "\e[1m#{str}\e[22m"
  end
end
