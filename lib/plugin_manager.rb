class PluginManager
  class HookAlreadyTriggered < StandardError; end

  def self.instance
    @instance ||= PluginManager.new
  end

  def add_plugin(label, plugin)
    raise ArgumentError unless label.present?
    raise ArgumentError if plugin_registered?(label)
    raise ArgumentError unless looks_like_plugin?(plugin)
    raise HookAlreadyTriggered if any_hook_triggered?

    plugins[label] = plugin

    self
  end

  def add_plugins(**plugins)
    plugins.each_pair do |label, plugin|
      add_plugin label, plugin
    end

    self
  end

  def any_hook_triggered?
    !!@any_hook_triggered
  end

  def looks_like_plugin?(plugin)
    plugin.present?
  end

  def plugin_registered?(label)
    plugins.include?(label)
  end

  def reset!
    @plugins = nil
    @any_hook_triggered = false
  end\

  def trigger_hook(
      hook,
      *args,
      **kwargs
    )
    @any_hook_triggered = true

    shuffled_plugins = plugins.values.shuffle

    shuffled_plugins.each do |plugin|
      plugin.send(hook, *args, **kwargs)
    end
  end

  private

  def plugins
    @plugins ||= {}
  end
end
