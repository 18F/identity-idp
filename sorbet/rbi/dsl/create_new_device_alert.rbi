# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `CreateNewDeviceAlert`.
# Please instead update this file by running `bin/tapioca dsl CreateNewDeviceAlert`.


class CreateNewDeviceAlert
  class << self
    sig do
      params(
        now: T.untyped,
        block: T.nilable(T.proc.params(job: CreateNewDeviceAlert).void)
      ).returns(T.any(CreateNewDeviceAlert, FalseClass))
    end
    def perform_later(now, &block); end

    sig { params(now: T.untyped).returns(T.untyped) }
    def perform_now(now); end
  end
end