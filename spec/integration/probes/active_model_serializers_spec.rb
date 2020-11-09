require "spec_helper"

begin
  require "active_model/serializer"
rescue LoadError
end

if defined?(ActiveModel::Serializer)
  describe "ActiveModel::Serializer", :active_model_serializers_probe, :agent, :instrumenter do
    require "action_controller"
    require "action_controller/serialization"

    # File changed name between versions
    %w[serializer serializers].each do |dir|
      require "active_model/#{dir}/version"
    rescue LoadError
    end

    version = Gem::Version.new(::ActiveModel::Serializer::VERSION)

    before do
      # We don't actually support the RCs correctly, requires
      # a release after 0.10.0.rc3
      if version >= Gem::Version.new("0.10.0.rc1")
        stub_const(
          "Item",
          Class.new(ActiveModelSerializers::Model) do
            attr_accessor :name, :value
          end
        )

        @original_adapter = ActiveModelSerializers.config.adapter
        ActiveModelSerializers.config.adapter = :json
      else
        stub_const(
          "Item",
          Class.new do
            include ActiveModel::SerializerSupport

            attr_accessor :name, :value

            def initialize(attributes = {})
              attributes.each do |key, val|
                send("#{key}=", val)
              end
            end
          end
        )
      end

      stub_const(
        "ItemSerializer",
        Class.new(ActiveModel::Serializer) do
          attributes :name, :doubled_value

          def doubled_value
            object.value * 2
          end
        end
      )

      stub_const(
        "ItemController",
        Class.new(ActionController::Base) do
          # This usually happens in a Railtie
          include ActionController::Serialization

          layout nil

          def list
            render json: items, root: "items"
          end

          def show
            render json: items.first
          end

          def anonymous_show
            render json: items.first, serializer: Class.new(ItemSerializer), root: "item"
          end

          # Used by AM::S (older only?)
          def url_options
            {}
          end

          private

            def items
              [Item.new(name: "Test", value: 2), Item.new(name: "Other", value: 5)]
            end
        end
      )
    end

    after do
      if instance_variable_defined?(:@original_adapter)
        ActiveModelSerializers.config.adapter = @original_adapter
      end
    end

    let :request do
      ActionDispatch::TestRequest.new("REQUEST_METHOD" => "GET", "rack.input" => "")
    end

    let :controller do
      ItemController.new
    end

    def dispatch(action)
      if controller.method(:dispatch).arity == 3
        controller.dispatch(action, request, ActionDispatch::TestResponse.new)
      else
        controller.dispatch(action, request)
      end
    end

    it "instruments serialization" do
      _status, _header, response = dispatch(:show)

      json = { item: { name: "Test", doubled_value: 4 } }.to_json
      expect(response.body).to eq(json)

      opts = {
        cat:   "view.render.active_model_serializers",
        title: "ItemSerializer"
      }

      if version >= Gem::Version.new("0.10.0.rc1")
        opts[:desc] = "Adapter: Json"
      end

      expect(current_trace.mock_spans[2]).to include(opts)
    end

    it "instruments array serialization" do
      _status, _header, response = dispatch(:list)

      json = { items: [{ name: "Test", doubled_value: 4 },
                       { name: "Other", doubled_value: 10 }] }.to_json
      expect(response.body).to eq(json)

      opts = {
        cat: "view.render.active_model_serializers"
      }

      if version >= Gem::Version.new("0.10.0.rc1")
        opts[:title] = "CollectionSerializer"
        opts[:desc] = "Adapter: Json"
      else
        opts[:title] = "ArraySerializer"
      end

      expect(current_trace.mock_spans[2]).to include(opts)
    end

    it "instruments anonymous serializers" do
      _status, _header, response = dispatch(:anonymous_show)

      json = { item: { name: "Test", doubled_value: 4 } }.to_json
      expect(response.body).to eq(json)

      opts = {
        cat:   "view.render.active_model_serializers",
        title: "<Anonymous Serializer>"
      }

      if version >= Gem::Version.new("0.10.0.rc1")
        opts[:desc] = "Adapter: Json"
      end

      expect(current_trace.mock_spans[2]).to include(opts)
    end
  end
end
