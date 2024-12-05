class FakeAnalytics < Analytics
  PiiDetected = Class.new(StandardError).freeze

  include AnalyticsEvents
  prepend Idv::AnalyticsEventsEnhancer

  module PiiAlerter
    def track_event(event, original_attributes = {})
      attributes = original_attributes.compact
      pii_like_keypaths = attributes.delete(:pii_like_keypaths) || []

      constant_name = Analytics.constants.find { |c| Analytics.const_get(c) == event }

      string_payload = attributes.to_json

      if string_payload.include?('pii') && !pii_like_keypaths.include?([:pii])
        raise PiiDetected, <<~ERROR
          track_event string 'pii' detected in attributes
          event: #{event} (#{constant_name})
          full event: #{attributes}"
        ERROR
      end

      Idp::Constants::MOCK_IDV_APPLICANT.slice(
        :first_name,
        :last_name,
        :address1,
        :dob,
        :state_id_number,
      ).each do |key, default_pii_value|
        if string_payload.match?(Regexp.new('\b' + Regexp.quote(default_pii_value) + '\b', 'i'))
          raise PiiDetected, <<~ERROR
            track_event example PII #{key} (#{default_pii_value}) detected in attributes
            event: #{event} (#{constant_name})
            full event: #{attributes}"
          ERROR
        end
      end

      pii_attr_names = Pii::Attributes.members + [:personal_key] - [
        :state, # state on its own is not enough to be a pii leak
      ]

      check_recursive = ->(value, keypath = []) do
        case value
        when Hash
          value.each do |key, val|
            current_keypath = keypath + [key]
            if pii_attr_names.include?(key) && !pii_like_keypaths.include?(current_keypath)
              raise PiiDetected, <<~ERROR
                track_event received pii key path: #{current_keypath.inspect}
                event: #{event} (#{constant_name})
                full event: #{attributes.inspect}
                allowlisted keypaths: #{pii_like_keypaths.inspect}
              ERROR
            end

            check_recursive.call(val, current_keypath)
          end
        when Array
          value.each { |val| check_recursive.call(val, keypath) }
        end
      end

      check_recursive.call(attributes)

      super(event, attributes)
    end
  end

  UndocumentedParams = Class.new(StandardError).freeze

  module UndocumentedParamsChecker
    mattr_accessor :allowed_extra_analytics
    mattr_accessor :checked_extra_analytics
    mattr_accessor :asts
    mattr_accessor :docstrings

    def track_event(event, original_attributes = {})
      method_name = caller.
        grep(/analytics_events\.rb/)&.
        first&.
        match(/:in `(?<method_name>[^']+)'/)&.
        [](:method_name)&.
        to_sym

      if method_name
        analytics_method = AnalyticsEvents.instance_method(method_name)

        param_names = analytics_method.
          parameters.
          select { |type, _name| [:keyreq, :key].include?(type) }.
          map(&:last)

        extra_keywords = original_attributes.keys \
          - [:pii_like_keypaths, :user_id] \
          - param_names \
          - option_param_names(analytics_method)

        if extra_keywords.present?
          @@checked_extra_analytics = checked_extra_analytics.to_a.concat(extra_keywords)

          extra_keywords -= Array(allowed_extra_analytics)

          if extra_keywords.present? && !allowed_extra_analytics.include?(:*)
            raise UndocumentedParams, <<~ERROR
              event :#{method_name} called with undocumented params #{extra_keywords.inspect}
              (if these params are for specs only, use :allowed_extra_analytics metadata)
            ERROR
          end
        end
      end

      super(event, original_attributes)
    end

    # @api private
    # Returns the names of @option tags from the source of a method
    def option_param_names(instance_method)
      self.asts ||= {}
      self.docstrings ||= {}

      if !YARD::Tags::Library.instance.has_tag?(:'identity.idp.previous_event_name')
        YARD::Tags::Library.define_tag('Previous Event Name', :'identity.idp.previous_event_name')
      end

      file = instance_method.source_location.first

      ast = self.asts[file] ||= begin
        YARD::Parser::Ruby::RubyParser.new(File.read(file), file).
          parse.
          ast
      end

      docstring = self.docstrings[instance_method.name] ||= begin
        node = ast.traverse do |node|
          break node if node.type == :def && node.jump(:ident)&.first == instance_method.name.to_s
        end

        YARD::DocstringParser.new.parse(node.docstring).to_docstring
      end

      docstring.tags.select { |tag| tag.tag_name == 'option' }.
        map { |tag| tag.pair.name.tr(%('"), '') }
    end
  end

  prepend PiiAlerter
  prepend UndocumentedParamsChecker

  attr_reader :events
  attr_accessor :user
  attr_accessor :session

  def initialize(user: AnonymousUser.new, sp: nil, session: nil)
    @events = Hash.new
    @user = user
    @sp = sp
    @session = session
  end

  def track_event(event, attributes = {})
    if attributes[:proofing_components].instance_of?(Idv::ProofingComponents)
      attributes[:proofing_components] = attributes[:proofing_components].as_json.symbolize_keys
    end
    events[event] ||= []
    events[event] << attributes
    nil
  end

  def browser_attributes
    {}
  end

  def reset!
    @events = Hash.new
  end
end

RSpec.configure do |c|
  groups = []

  c.around do |ex|
    keys = Array(ex.metadata[:allowed_extra_analytics])
    FakeAnalytics::UndocumentedParamsChecker.allowed_extra_analytics = keys
    ex.run

    if keys.present?
      group = ex.example_group
      group = group.superclass until [nil, RSpec::Core::ExampleGroup].include?(group.superclass)
      groups << [group, FakeAnalytics::UndocumentedParamsChecker.checked_extra_analytics.to_a]
    end
  ensure
    FakeAnalytics::UndocumentedParamsChecker.allowed_extra_analytics = []
    FakeAnalytics::UndocumentedParamsChecker.checked_extra_analytics = []
  end

  c.after(:all) do |_ex|
    next if c.world.all_examples.count != c.world.example_count

    groups.group_by(&:first).each do |group, pairs|
      allowed_extra_analytics = group.metadata[:allowed_extra_analytics]
      next if allowed_extra_analytics.blank?
      all_checked_extra_analytics = pairs.map(&:last).flatten.uniq
      if allowed_extra_analytics.include?(:*)
        expect(all_checked_extra_analytics).to(
          be_present,
          "Unnecessary allowed_extra_analytics on example group #{group} (in #{group.id})",
        )
      else
        unchecked_extra_analytics = allowed_extra_analytics - all_checked_extra_analytics
        expect(unchecked_extra_analytics).to(
          be_blank,
          "Unnecessary allowed_extra_analytics keywords on example group #{group}: " \
            "#{unchecked_extra_analytics} (in #{group.id})",
        )
      end
    end
  ensure
    groups = []
  end
end
