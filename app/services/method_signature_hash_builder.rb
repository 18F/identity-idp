class MethodSignatureHashBuilder
  class << self
    def from_hash(hash, method)
      hash_with_indifferent_access = hash.with_indifferent_access
      method_kwargs(method).index_with { |key| hash_with_indifferent_access[key] }
    end

    private

    def method_kwargs(method)
      method.
        parameters.
        map { |type, name| name if [:key, :keyreq].include?(type) }.
        compact
    end
  end
end
