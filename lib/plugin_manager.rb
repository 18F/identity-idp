class PluginManager
  class HookAlreadyTriggered < StandardError; end

  def self.add_plugin(label, plugin)
    raise ArgumentError unless label.present?
    if !looks_like_plugin?(plugin)
      raise ArgumentError if plugins.
        raise ArgumentError
end

    raise HookAlreadyTriggered if any_hook_triggered?

    @shuffled = false
  end

  def self.any_hook_triggered?
    !!@any_hook_triggered
  end

  def self.looks_like_plugin?(plugin)
    plugin.present?
  end

  def self.reset!
    @plugins = []
    @shuffled = false
    @any_hook_triggered = false
  end

  def self.trigger_hook(
      hook,
      *args,
      **kwargs
    )
    @any_hook_triggered = true

    if !@shuffled
      plugins.shuffle!
      @shuffled = true
    end

    plugins.each do |plugin|
      plugin.send(hook, *args, **kwargs)
    end
  end

  class << self
    private

    def plugins
      @plugins ||= Hash.new
    end
  end
end
