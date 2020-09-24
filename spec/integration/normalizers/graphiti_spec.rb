# frozen_string_literal: true

require "spec_helper"
require "skylight/instrumenter"

begin
  require "graphiti"
rescue LoadError
  warn "Skipping Graphiti tests since it isn't installed."
end

if defined?(Graphiti)
  describe "Graphiti integration", :agent do
    module GraphitiTests
      class Author
        # Define getters/setters
        # e.g. post.title = 'foo'
        ATTRS = %i[id name].freeze
        ATTRS.each { |a| attr_accessor(a) }

        # Instantiate with hash of attributes
        # e.g. Author.new(name: 'foo')
        def initialize(attrs = {})
          attrs.each_pair { |k, v| send(:"#{k}=", v) }
        end

        # This part only needed for our particular
        # persistence implementation; you may not need it
        # e.g. post.attributes # => { title: 'foo' }
        def attributes
          {}.tap do |attrs|
            ATTRS.each do |name|
              attrs[name] = send(name)
            end
          end
        end
      end

      class Post
        # Define getters/setters
        # e.g. post.title = 'foo'
        ATTRS = %i[id author_id author title].freeze
        ATTRS.each { |a| attr_accessor(a) }

        # Instantiate with hash of attributes
        # e.g. Post.new(title: 'foo')
        def initialize(attrs = {})
          attrs.each_pair { |k, v| send(:"#{k}=", v) }
        end

        # This part only needed for our particular
        # persistence implementation; you may not need it
        # e.g. post.attributes # => { title: 'foo' }
        def attributes
          {}.tap do |attrs|
            ATTRS.each do |name|
              attrs[name] = send(name)
            end
          end
        end
      end

      class AuthorResource < Graphiti::Resource
        self.validate_endpoints = false
        self.adapter = Graphiti::Adapters::Null

        DATA = [
          { id: 1, name: "Peter" },
          { id: 2, name: "Lee" },
          { id: 3, name: "Wade" }
        ].freeze

        has_many :posts
        attribute :name, :string

        def base_scope
          {}
        end

        def resolve(_scope)
          DATA.map { |d| Author.new(d) }
        end
      end

      class PostResource < Graphiti::Resource
        self.validate_endpoints = false
        self.adapter = Graphiti::Adapters::Null

        DATA = [
          { id: 1, author_id: 1, title: "Graphiti" },
          { id: 2, author_id: 2, title: "is" },
          { id: 3, author_id: 3, title: "super" },
          { id: 4, author_id: 4, title: "dope" }
        ].freeze

        belongs_to :author
        attribute :title, :string

        def base_scope
          {}
        end

        def resolve(_scope)
          DATA.map { |d| Post.new(d) }
        end
      end
    end

    around do |example|
      Skylight.mock!
      Skylight.trace do
        example.run
      end
    ensure
      Skylight.stop!
    end

    before do
      # Graphiti has some checks for Rails that assume that if Rails is defined then other methods will be.
      # These assumptions aren't always correct so just undefined Rails for these specs.
      stub_const("Rails", double("Rails").as_null_object)
    end

    let(:trace) do
      Skylight.instrumenter.current_trace
    end

    it "instruments resolve and render" do
      results = GraphitiTests::PostResource.all

      expect(trace).to receive(:instrument).
        with("app.resolve.graphiti", "Resolve Primary GraphitiTests::PostResource", nil, {})

      # Force a resolve
      results.to_a

      expect(trace).to receive(:instrument).
        with("view.render.graphiti", "Render GraphitiTests::PostResource", nil, {})

      # Now render
      results.to_jsonapi
    end

    it "instruments sideloading" do
      expect(trace).to receive(:instrument).
        with("app.resolve.graphiti", "Resolve Primary GraphitiTests::PostResource", nil, {})
      expect(trace).to receive(:instrument).
        with("app.resolve.graphiti", "Resolve Belongs To GraphitiTests::AuthorResource", nil, {})
      expect(trace).to receive(:instrument).
        with("view.render.graphiti", "Render GraphitiTests::PostResource", nil, {})

      GraphitiTests::PostResource.all(include: :author).to_jsonapi
    end

    it "instruments anonymous classes" do
      resource = Class.new(Graphiti::Resource) do
        self.adapter = Graphiti::Adapters::Null

        def base_scope
          {}
        end

        def resolve(_scope)
          []
        end
      end

      expect(trace).to receive(:instrument).
        with("app.resolve.graphiti", "Resolve Primary <Anonymous Resource>", nil, {})
      expect(trace).to receive(:instrument).
        with("view.render.graphiti", "Render <Anonymous Resource>", nil, {})

      resource.all.to_jsonapi
    end
  end
end
