class Redirector
  class AmbiguousRedirect < StandardError
  end

  NORMAL_PRIORITY = 0
  HIGH_PRIORITY = 100

  def initialize(scheduled_redirects: [], source: nil, &block)
    @scheduled_redirects = scheduled_redirects
    @source = source
    @block = block
  end

  def redirect_to(*args, **kwargs)
    scheduled_redirects.append(
      {
        priority: NORMAL_PRIORITY,
        args: args,
        kwargs: kwargs,
        source: source,
      },
    )
    self
  end

  def redirect_with_high_priority_to(*_args, **_kwargs)
    scheduled_redirects.append(
      {
        priority: HIGH_PRIORITY,
        args: args,
        kwargs: kwargs,
        source: source,
      },
    )
    self
  end

  def resolve!
    return if scheduled_redirects.empty?

    if scheduled_redirects.count == 1
      r = scheduled_redirects.first
      return block.call(*r[:args], **r[:kwargs])
    end

    sorted = scheduled_redirects.sort_by { |r| r[:priority] * -1 }

    if sorted[0][:priority] == sorted[1][:priority]
      raise AmbiguousRedirect
    end

    r = sorted.first
    block.call(*r[:args], **r[:kwargs])
  end

  def with_source(new_source)
    Redirector.new(scheduled_redirects: scheduled_redirects, source: new_source, block: block)
  end

  private

  attr_reader :block, :scheduled_redirects, :source
end
