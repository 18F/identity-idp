module Upaya
  module RandomTools
    # rubocop:disable MethodLength, Style/IfUnlessModifier, Metrics/AbcSize

    # Randomly choose an item among choices with integer weights. For example,
    # if passed `{'a' => 3, 'b' => 1}`, the expected return value will approach
    # 'a' 75% of the time and 'b' 25% of the time.
    #
    # @param [Hash{Object => Integer}] choices A mapping from each choice to an
    #   integer weight. The weights will be relative to the sum of all weights.
    #
    # @return [Object] One of the keys chosen from the choices hash.
    #
    def self.random_weighted_sample(choices)
      if choices.empty?
        raise ArgumentError, 'Cannot choose among empty choices hash'
      end

      sum = 0
      choices.each_pair do |item, weight|
        unless weight.is_a?(Integer) && weight >= 0
          raise ArgumentError, "Choices must have >= 0 integer weights, " \
            "got #{item.inspect} => #{weight.inspect}"
        end
        sum += weight
      end

      if sum.zero?
        raise ArgumentError, 'Must have non-zero weight among choices'
      end

      target = rand(sum)

      choices.each_pair do |item, weight|
        return item if target < weight
        target -= weight
      end

      raise NotImplementedError, 'This line should not be reached'
    end

    # rubocop:enable MethodLength, Style/IfUnlessModifier, Metrics/AbcSize
  end
end
