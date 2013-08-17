describe "Skylight::Messages::AnnotationBuilder" do
  def build(annotations)
    Skylight::Messages::AnnotationBuilder.build(annotations)
  end

  it "takes an empty hash and returns an instance of Annotation" do
    build({}).should == []
  end

  it "takes a hash containing a string value" do
    build({ foo: "bar" }).should == [annotation("foo", :string, "bar")]
  end

  it "takes a hash containing a integer value" do
    build({ foo: 1 }).should == [annotation("foo", :int, 1)]
  end

  it "takes a hash containing a double value" do
    build({ foo: 1.5 }).should == [annotation("foo", :double, 1.5)]
  end

  it "supports multiple root nodes" do
    build({ foo: 1, bar: 2 }).should == [annotation("foo", :int, 1), annotation("bar", :int, 2)]
  end

  it "takes a hash containing a nested hash" do
    build({ foo: { bar: "baz" } }).should ==
      [annotation("foo") do |n2|
        n2 << annotation("bar", :string, "baz")
      end]
  end

  it "takes a hash containing a nested array" do
    build({ foo: [ "bar", "baz", 1, 2 ] }).should ==
      [annotation("foo") do |n|
        n << annotation(nil, :string, "bar")
        n << annotation(nil, :string, "baz")
        n << annotation(nil, :int, 1)
        n << annotation(nil, :int, 2)
      end]
  end

  it "supports complex nested structures" do
    build({ foo: { bar: { baz: "bat" }, bam: 1, zomg: 1.5, omg: [ -1.5, { zomg: 2, wat: "foo" } ] } }).should ==
      [annotation("foo") do |n2|
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
      end]
  end
end
