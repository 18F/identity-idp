# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `Ahoy::GeocodeJob`.
# Please instead update this file by running `bin/tapioca dsl Ahoy::GeocodeJob`.


class Ahoy::GeocodeJob
  class << self
    sig do
      params(
        visit: T.untyped,
        block: T.nilable(T.proc.params(job: Ahoy::GeocodeJob).void)
      ).returns(T.any(Ahoy::GeocodeJob, FalseClass))
    end
    def perform_later(visit, &block); end

    sig { params(visit: T.untyped).returns(T.untyped) }
    def perform_now(visit); end
  end
end