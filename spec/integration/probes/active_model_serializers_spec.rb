require 'spec_helper'

if defined?(ActiveModel::Serializer)
  describe 'ActiveModel::Serializer', :active_model_serializers_probe, :agent, :instrumenter do

    require 'action_controller'
    require 'action_controller/serialization'

    # File changed name between versions
    %w(serializer serializers).each do |dir|
      begin
        require "active_model/#{dir}/version"
      rescue LoadError
      end
    end

    version = Gem::Version.new(::ActiveModel::Serializer::VERSION)

    # We don't actually support the RCs correctly, requires
    # a release after 0.10.0.rc3
    if version >= Gem::Version.new("0.10.0.rc1")
      class Item < ActiveModelSerializers::Model
        attr_accessor :name, :value
      end

      # This usually happens in a Railtie
      ActionController::Base.send(:include, ActionController::Serialization)

      ActiveModelSerializers.config.adapter = :json
    else
      class Item
        include ActiveModel::SerializerSupport

        attr_accessor :name, :value

        def initialize(attributes={})
          attributes.each do |key, val|
            self.send("#{key}=", val)
          end
        end
      end
    end


    class ItemSerializer < ActiveModel::Serializer
      attributes :name, :doubled_value

      def doubled_value
        object.value * 2
      end
    end

    class ItemController < ActionController::Base
      layout nil

      def list
        render json: items, root: "items"
      end

      def show
        render json: items.first
      end

      # Used by AM::S (older only?)
      def url_options; {} end

      # Work without routes in Rails 3.0
      def method_for_action(action_name)
        action_name
      end

      private

        def items
          [Item.new(name: "Test", value: 2), Item.new(name: "Other", value: 5)]
        end
    end

    let :request do
      ActionDispatch::TestRequest.new('REQUEST_METHOD' => 'GET', 'rack.input' => '')
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

    before :each do
      # When running with Rails 3.0 this gets defined but is nil
      if defined?(Rails.application) && !Rails.application
        application = double(env_defaults: {}, env_config: {}, config: nil)
        allow(Rails).to receive(:application).and_return(application)
      end
    end

    it "instruments serialization" do
      status, header, response = dispatch(:show)

      json = { item: { name: "Test", doubled_value: 4 }}.to_json
      expect(response.body).to eq(json)

      opts = {
        cat: 'view.render.active_model_serializers',
        title: "ItemSerializer"
      }

      if version >= Gem::Version.new("0.10.0.rc1")
        opts[:desc] = "Adapter: Json"
      end

      expect(current_trace.mock_spans[2]).to include(opts)
    end

    it "instruments array serialization" do
      status, header, response = dispatch(:list)

      json = { items: [{ name: "Test", doubled_value: 4 },
                        { name: "Other", doubled_value: 10 }]}.to_json
      expect(response.body).to eq(json)

      opts = {
        cat: 'view.render.active_model_serializers'
      }

      if version >= Gem::Version.new("0.10.0.rc1")
        opts[:title] = "CollectionSerializer"
        opts[:desc] = "Adapter: Json"
      else
        opts[:title] = "ArraySerializer"
      end

      expect(current_trace.mock_spans[2]).to include(opts)
    end

  end
end