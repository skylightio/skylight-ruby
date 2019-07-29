require "spec_helper"
require "skylight/core/instrumenter"

enable = false
begin
  require "graphql"
  require "active_record"
  enable = true
rescue LoadError
  puts "[INFO] Skipping graphql integration specs"
end

if enable
  module TestApp
    module Types
      class BaseObject < GraphQL::Schema::Object; end
      class SpeciesFooType < BaseObject
        field :name, String, null: false
        field :common_name, String, null: false
        field :scientific_name, String, null: false
      end

      class GenusType < BaseObject
        field :species, [SpeciesFooType], null: false
      end

      class FamilyType < BaseObject
        field :genera, [GenusType], null: false
        field :species, [SpeciesFooType], null: false
      end

      class QueryType < BaseObject
        field :some_dragonflies, [String], null: false,
          description: "A list of some of the dragonflies"

        field :families, [Types::FamilyType], null: false,
          description: "A list of families"

        field :family, Types::FamilyType, null: false, description: "A specific family" do
          argument :name, String, required: true
        end

        def some_dragonflies
          Species.all
        end

        def family(name:)
          ::Family.find_by!(name: name)
        end
      end
    end

    class TestAppSchema < GraphQL::Schema
      use GraphQL::Execution::Interpreter

      tracer(GraphQL::Tracing::ActiveSupportNotificationsTracing)

      # FIXME: add/test mutations
      # mutation(Types::MutationType)
      query(Types::QueryType)
    end
  end


  describe "graphql integration" do
    around do |example|
      ActiveSupport::Inflector.inflections(:en) do |inflect|
        inflect.irregular 'genus', 'genera'
      end

      with_sqlite(migration: migration, &example)
    end

    def seed_db
      [
        { common: 'Variable Darner', latin: 'Aeshna interrupta', family: 'Aeshnidae' },
        { common: 'California Darner', latin: 'Rhionaeschna californica', family: 'Aeshnidae' },
        { common: 'Blue-Eyed Darner', latin: 'Rhionaeschna multicolor', family: 'Aeshnidae' },
        { common: 'Cardinal Meadowhawk', latin: 'Sympetrum illotum', 	family: 'Libellulidae' },
        { common: 'Variegated Meadowhawk', latin: 'Sympetrum corruptum', 	family: 'Libellulidae' },
        { common: 'Western Pondhawk', latin: 'Erythemis collocata', family: 'Libellulidae' },
        { common: 'Common Whitetail', latin: 'Plathemis lydia',	family: 'Libellulidae' },
        { common: 'Twelve-Spotted Skimmer', latin: 'Libellula pulchella',	family: 'Libellulidae' },
        { common: 'Black Saddlebags', latin: 'Tramea lacerata',	family: 'Libellulidae' },
        { common: 'Wandering Glider', latin: 'Pantala flavescens', family: 'Libellulidae' },
        { common: 'Vivid Dancer', latin: 'Argia vivida', family: 'Coenagrionidae' },
        { common: 'Boreal Bluet', latin: 'Enallagma boreale', family: 'Coenagrionidae' },
        { common: 'Tule Bluet', latin: 'Enallagma carunculatum', family: 'Coenagrionidae' },
        { common: 'Pacific Forktail', latin: 'Ischnura cervula', family: 'Coenagrionidae' },
        { common: 'Western Forktail', latin: 'Ischnura perparva', family: 'Coenagrionidae' },
        { common: 'White-belted Ringtail', latin: 'Erpetogomphus compositus', family: 'Gomphidae' },
        { common: 'Dragonhunter', latin: 'Hagenius brevistylus', family: 'Gomphidae' },
        { common: 'Sinuous Snaketail', latin: 'Ophiogomphus occidentis', family: 'Gomphidae' },
        { common: 'Mountain Emerald', latin: 'Somatochlora semicircularis', family: 'Corduliidae' },
        { common: 'Beaverpond Baskettail', latin: 'Epitheca canis', family: 'Corduliidae' },
        { common: 'Ebony Boghaunter', latin: 'Williamsonia fletcheri', family: 'Corduliidae' },
      ].each do |entry|
        family = Family.find_or_create_by!(name: entry[:family])
        g, s = entry[:latin].split(' ')
        genus = Genus.find_or_create_by!(name: g, family: family)
        Species.create!(name: s, genus: genus, common_name: entry[:common])
      end
    end

    let(:migration) do
      base = ActiveRecord::Migration
      base = defined?(base::Current) ? base::Current : base

      Class.new(base) do
        def self.up
          create_table :families, force: true do |t|
            t.string :name, index: true
          end

          create_table :genera, force: true do |t|
            t.string :name, index: true
            t.integer :family_id, index: true
          end

          create_table :species, force: true do |t|
            t.string :name
            t.string :common_name
            t.integer :genus_id
          end
        end

        def self.down
          drop_table :species
          drop_table :genus
          drop_table :families
        end
      end
    end

    before :each do
      @original_env = ENV.to_hash
      set_agent_env
      Skylight.start!

      class ApplicationRecord < ActiveRecord::Base
        self.abstract_class = true
      end

      class Family < ApplicationRecord
        has_many :genera
        has_many :species, through: :genera
      end

      class Genus < ApplicationRecord
        has_many :species
        belongs_to :family
      end

      class Species < ApplicationRecord
        belongs_to :genus
        has_one :family, through: :genus

        def scientific_name
          "#{genus.name} #{name}"
        end
      end

      seed_db

      class ::MyApp
        def call(env)
          request = Rack::Request.new(env)

          params = request.params.with_indifferent_access
          variables = params[:variables]
          context = {
            # Query context goes here, for example:
            # current_user: current_user,
          }

          result = if params[:queries]
            formatted_queries = params[:queries].map do |q|
              {
                query: q,
                variables: variables,
                context: context
              }
            end

            TestApp::TestAppSchema.multiplex(formatted_queries)
          else
            TestApp::TestAppSchema.execute(params[:query],
                                           variables: variables,
                                           context: context,
                                           operation_name: params[:operation_name])
          end

          # Normally Rails would set this as content_type, but this app doesn't
          # use Rails controllers.
          Skylight.trace.segment = 'json'
          [200, {}, result]
        end
      end
    end

    after :each do
      ENV.replace(@original_env)

      Skylight.stop!

      # Clean slate
      Object.send(:remove_const, :MyApp)
    end

    let :app do
      Rack::Builder.new do
        use Skylight::Middleware
        run MyApp.new
      end
    end

    context "with agent", :http, :agent do
      before :each do
        stub_config_validation
        stub_session_request
      end

      def make_graphql_request(query:)
        call env("/", method: :POST, params: { query: query })
      end

      context "with single queries" do
        it "successfully calls into graphql with anonymous queries", :anonymous do
          res = make_graphql_request(query: "query { someDragonflies }")

          server.wait resource: "/report"

          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]

          expect(endpoint.name).to eq("graphql:[anonymous]<sk-segment>json</sk-segment>")
          expect(endpoint.traces.count).to eq(1)
          trace = endpoint.traces[0]

          data = trace.filtered_spans.map { |s| [s.event.category, s.event.title] }

          query_name = "[anonymous]"
          expect(data).to eq([
            ["app.rack.request", nil],
            ["app.graphql", "graphql.execute_multiplex"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.analyze_query"],
            ["app.graphql", "graphql.execute_query: #{query_name}"],
            ["app.graphql", "graphql.execute_query_lazy: #{query_name}"]
          ])
        end

        it "successfully calls into graphql with named queries", :named do
          res = call env("/test", method: :POST, params: {
            operationName: "Anisoptera", # This is optional if there is only one query node
            query: "query Anisoptera { someDragonflies }" })

          server.wait resource: "/report"

          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]

          expect(endpoint.name).to eq("graphql:Anisoptera<sk-segment>json</sk-segment>")
          expect(endpoint.traces.count).to eq(1)
          trace = endpoint.traces[0]

          data = trace.filtered_spans.map { |s| [s.event.category, s.event.title] }

          query_name = "Anisoptera"
          expect(data).to eq([
            ["app.rack.request", nil],
            ["app.graphql", "graphql.execute_multiplex"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.analyze_query"],
            ["app.graphql", "graphql.execute_query: #{query_name}"],
            ["db.sql.query", "SELECT FROM species"],
            ["db.active_record.instantiation", "Species Instantiation"],
            ["app.graphql", "graphql.execute_query_lazy: #{query_name}"]
          ])
        end
      end

      context "with multiplex queries", :multiplex do
        it "successfully calls into graphql with anonymous queries", :anonymous do
          queries = ["query { someDragonflies }"].cycle.take(3)

          res = call env("/test", method: :POST, params: { queries: queries })

          server.wait resource: "/report"

          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]

          expect(endpoint.name).to eq("graphql:[anonymous]<sk-segment>json</sk-segment>")
          expect(endpoint.traces.count).to eq(1)
          trace = endpoint.traces[0]

          data = trace.filtered_spans.map { |s| [s.event.category, s.event.title] }

          query_name = "[anonymous]"
          expect(data).to eq([
            ["app.rack.request", nil],
            ["app.graphql", "graphql.execute_multiplex"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.analyze_query"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.analyze_query"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.analyze_query"],
            ["app.graphql", "graphql.execute_query: #{query_name}"],
            ["app.graphql", "graphql.execute_query: #{query_name}"],
            ["app.graphql", "graphql.execute_query: #{query_name}"],
            ["app.graphql", "graphql.execute_query_lazy.multiplex"]
          ])
        end

        it "successfully calls into graphql with name and anonymous queries", :anonymous, :named do
          queries = ["query { someDragonflies }"].cycle.take(3)
          queries.push("query myFavoriteDragonflies { someDragonflies }")

          res = call env("/test", method: :POST, params: { queries: queries })

          server.wait resource: "/report"

          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]

          expect(endpoint.name).to eq("graphql:[anonymous]+myFavoriteDragonflies<sk-segment>json</sk-segment>")
          expect(endpoint.traces.count).to eq(1)
          trace = endpoint.traces[0]

          data = trace.filtered_spans.map { |s| [s.event.category, s.event.title] }

          query_name = "[anonymous]"
          expect(data).to eq([
            ["app.rack.request", nil],
            ["app.graphql", "graphql.execute_multiplex"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.analyze_query"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.analyze_query"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.analyze_query"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.analyze_query"],
            ["app.graphql", "graphql.execute_query: #{query_name}"],
            ["app.graphql", "graphql.execute_query: #{query_name}"],
            ["app.graphql", "graphql.execute_query: #{query_name}"],
            ["app.graphql", "graphql.execute_query: myFavoriteDragonflies"],
            ["db.sql.query", "SELECT FROM species"],
            ["db.active_record.instantiation", "Species Instantiation"],
            ["app.graphql", "graphql.execute_query_lazy.multiplex"]
          ])
        end

        it "successfully calls into graphql with named queries", :named do
          queries = [
            "query myFavoriteDragonflies { someDragonflies }",
            "query kindOfOkayDragonflies { someDragonflies }"
          ]

          res = call env("/test", method: :POST, params: { queries: queries })

          server.wait resource: "/report"

          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]

          expect(endpoint.name).to eq("graphql:kindOfOkayDragonflies+myFavoriteDragonflies<sk-segment>json</sk-segment>")
          expect(endpoint.traces.count).to eq(1)
          trace = endpoint.traces[0]

          data = trace.filtered_spans.map { |s| [s.event.category, s.event.title] }

          expect(data).to eq([
            ["app.rack.request", nil],
            ["app.graphql", "graphql.execute_multiplex"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.analyze_query"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.analyze_query"],
            ["app.graphql", "graphql.execute_query: myFavoriteDragonflies"],
            ["db.sql.query", "SELECT FROM species"],
            ["db.active_record.instantiation", "Species Instantiation"],
            ["app.graphql", "graphql.execute_query: kindOfOkayDragonflies"],
            ["db.sql.query", "SELECT FROM species"],
            ["db.active_record.instantiation", "Species Instantiation"],
            ["app.graphql", "graphql.execute_query_lazy.multiplex"]
          ])
        end

        it "reports a compound segment" do
          queries = [
            "query myFavoriteDragonflies { someDragonflies }",
            "query kindOfOkayDragonflies { missingField }"
          ]

          res = call env("/test", method: :POST, params: { queries: queries })

          expect(res.last.to_h.key?("errors")).to eq(true)

          server.wait resource: "/report"

          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]

          expect(endpoint.name).to eq("graphql:kindOfOkayDragonflies+myFavoriteDragonflies<sk-segment>json+error</sk-segment>")
          expect(endpoint.traces.count).to eq(1)
          trace = endpoint.traces[0]

          data = trace.filtered_spans.map { |s| [s.event.category, s.event.title] }

          expect(data).to eq([
            ["app.rack.request", nil],
            ["app.graphql", "graphql.execute_multiplex"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.analyze_query"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.execute_query: myFavoriteDragonflies"],
            ["db.sql.query", "SELECT FROM species"],
            ["db.active_record.instantiation", "Species Instantiation"],
            ["app.graphql", "graphql.execute_query_lazy.multiplex"]
          ])
        end

        it "reports a compound error" do
          queries = [
            "query myFavoriteDragonflies { missingField }",
            "query kindOfOkayDragonflies { missingField }"
          ]

          res = call env("/test", method: :POST, params: { queries: queries })

          expect(res.last.to_h.key?("errors")).to eq(true)

          server.wait resource: "/report"

          batch = server.reports[0]
          expect(batch).to_not be nil
          expect(batch.endpoints.count).to eq(1)
          endpoint = batch.endpoints[0]

          expect(endpoint.name).to eq("graphql:kindOfOkayDragonflies+myFavoriteDragonflies<sk-segment>error</sk-segment>")
          expect(endpoint.traces.count).to eq(1)
          trace = endpoint.traces[0]

          data = trace.filtered_spans.map { |s| [s.event.category, s.event.title] }

          expect(data).to eq([
            ["app.rack.request", nil],
            ["app.graphql", "graphql.execute_multiplex"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.lex"],
            ["app.graphql", "graphql.parse"],
            ["app.graphql", "graphql.validate"],
            ["app.graphql", "graphql.execute_query_lazy.multiplex"]
          ])
        end
      end
    end

    def call(env)
      resp = app.call(env)
      consume(resp)
    end

    def env(path = "/", opts = {})
      Rack::MockRequest.env_for(path, opts)
    end

    def consume(resp)
      data = []
      resp[2].each { |p| data << p }
      resp[2].close if resp[2].respond_to?(:close)
      data
    end
  end
end
