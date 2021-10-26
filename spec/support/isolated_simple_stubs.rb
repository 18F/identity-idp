class IsolatedSimpleStubs < ActiveSupport::Testing::SimpleStubs
  def stub_object(object, method_name, &block)
    new_name = "__simple_stub__#{method_name}__#{object_id}"

    @stubs[object.object_id][method_name] = Stub.new(object, method_name, new_name)

    object.singleton_class.send :alias_method, new_name, method_name
    object.define_singleton_method(method_name, &block)
  end
end
