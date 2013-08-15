RSpec::Matchers.define(:deserialize_to) do |expected|
  match do |actual|
    expected == Skylight::Messages::Annotation.decode(actual.buf.dup)
  end

  failure_message_for_should do |actual|
    "#{Skylight::Messages::Annotation.decode(actual.buf.dup).inspect} should deserialize to #{expected.inspect}"
  end
end

describe "Skylight::Messages::AnnotationBuilder" do
  def build(annotations)
    Skylight::Messages::AnnotationBuilder.build(annotations)
  end

  def annotation(key=nil, type=nil, value=nil, &block)
    Skylight::Messages::Annotation.new.tap do |annotation|
      annotation.key = key if key
      annotation[type] = value if value

      if block_given?
        annotation.nested = []
        yield annotation.nested
      end
    end
  end

  it "takes an empty hash and returns an instance of Annotation" do
    build({}).should deserialize_to(Skylight::Messages::Annotation.new)
  end

  it "takes a hash containing a string value" do
    build({ foo: "bar" }).should deserialize_to(
      annotation do |nested|
        nested << annotation("foo", :string, "bar")
      end
    )
  end

  it "takes a hash containing a integer value" do
    build({ foo: 1 }).should deserialize_to(
      annotation do |nested|
        nested << annotation("foo", :int, 1)
      end
    )
  end

  it "takes a hash containing a double value" do
    build({ foo: 1.5 }).should deserialize_to(
      annotation do |nested|
        nested << annotation("foo", :double, 1.5)
      end
    )
  end

  it "takes a hash containing a nested hash" do
    build({ foo: { bar: "baz" } }).should deserialize_to(
      annotation do |n1|
        n1 << annotation("foo") do |n2|
          n2 << annotation("bar", :string, "baz")
        end
      end
    )
  end

  it "takes a hash containing a nested array" do
    build({ foo: [ "bar", "baz", 1, 2 ] }).should deserialize_to(
      annotation do |n1|
        n1 << annotation("foo") do |n2|
          n2 << annotation(nil, :string, "bar")
          n2 << annotation(nil, :string, "baz")
          n2 << annotation(nil, :int, 1)
          n2 << annotation(nil, :int, 2)
        end
      end
    )
  end

  it "supports complex nested structures" do
    build({ foo: { bar: { baz: "bat" }, bam: 1, zomg: 1.5, omg: [ -1.5, { zomg: 2, wat: "foo" } ] } }).should deserialize_to(
      annotation do |n1|
        n1 << annotation("foo") do |n2|
          n2 << annotation("bar") do |n3|
            n3 << annotation("baz", :string, "bat")
          end
          n2 << annotation("bam", :int, 1)
          n2 << annotation("zomg", :double, 1.5)
          n2 << annotation("omg") do |n3|
            n3 << annotation(nil, :double, -1.5)
            n3 << annotation do |n4|
              n4 << annotation("zomg", :int, 2)
              n4 << annotation("wat", :string, "foo")
            end
          end
        end
      end
    )
  end
end
