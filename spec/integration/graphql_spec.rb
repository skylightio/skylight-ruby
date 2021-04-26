require "spec_helper"
require "skylight/instrumenter"

enable = false
begin
  require "graphql"
  require "active_record"
  enable = true
rescue LoadError
  puts "[INFO] Skipping graphql integration specs"
end

if enable
  def test_interpreter_schema?
    defined?(GraphQL::Execution::Interpreter)
  end

  describe "graphql integration" do
    around do |example|
      ActiveSupport::Inflector.inflections(:en) { |inflect| inflect.irregular "genus", "genera" }

      with_sqlite(migration: migration, &example)
    end

    def seed_db
      [
        { common: "Variable Darner", latin: "Aeshna interrupta", family: "Aeshnidae" },
        { common: "California Darner", latin: "Rhionaeschna californica", family: "Aeshnidae" },
        { common: "Blue-Eyed Darner", latin: "Rhionaeschna multicolor", family: "Aeshnidae" },
        { common: "Cardinal Meadowhawk", latin: "Sympetrum illotum", family: "Libellulidae" },
        { common: "Variegated Meadowhawk", latin: "Sympetrum corruptum", family: "Libellulidae" },
        { common: "Western Pondhawk", latin: "Erythemis collocata", family: "Libellulidae" },
        { common: "Common Whitetail", latin: "Plathemis lydia", family: "Libellulidae" },
        { common: "Twelve-Spotted Skimmer", latin: "Libellula pulchella", family: "Libellulidae" },
        { common: "Black Saddlebags", latin: "Tramea lacerata", family: "Libellulidae" },
        { common: "Wandering Glider", latin: "Pantala flavescens", family: "Libellulidae" },
        { common: "Vivid Dancer", latin: "Argia vivida", family: "Coenagrionidae" },
        { common: "Boreal Bluet", latin: "Enallagma boreale", family: "Coenagrionidae" },
        { common: "Tule Bluet", latin: "Enallagma carunculatum", family: "Coenagrionidae" },
        { common: "Pacific Forktail", latin: "Ischnura cervula", family: "Coenagrionidae" },
        { common: "Western Forktail", latin: "Ischnura perparva", family: "Coenagrionidae" },
        { common: "White-belted Ringtail", latin: "Erpetogomphus compositus", family: "Gomphidae" },
        { common: "Dragonhunter", latin: "Hagenius brevistylus", family: "Gomphidae" },
        { common: "Sinuous Snaketail", latin: "Ophiogomphus occidentis", family: "Gomphidae" },
        { common: "Mountain Emerald", latin: "Somatochlora semicircularis", family: "Corduliidae" },
        { common: "Beaverpond Baskettail", latin: "Epitheca canis", family: "Corduliidae" },
        { common: "Ebony Boghaunter", latin: "Williamsonia fletcheri", family: "Corduliidae" }
      ].each do |entry|
        family = Family.find_or_create_by!(name: entry[:family])
        g, s = entry[:latin].split(" ")
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

    # prettier-ignore
    before :each do
      stub_const("TestApp", Module.new {})

      TestApp.module_eval <<~RUBY, __FILE__, __LINE__ + 1
        mattr_accessor :current_schema

        def self.graphql17?
          return @graphql17 if defined?(@graphql17)

          @graphql17 = Gem::Version.new(GraphQL::VERSION) < Gem::Version.new("1.8")
        end

        def self.format_field_name(field)
          # As of graphql 1.8, client-side queries are expected to have camel-cased keys
          # (these are converted to snake-case server-side).
          # In 1.7 and earlier, they used whatever format was used to define the schema.
          graphql17? ? field.underscore : field.camelize(:lower)
        end

        if graphql17?
          module Types
            SpeciesType =
              GraphQL::ObjectType.define do
                name "Species"
                field :name, !types.String
                field :common_name, !types.String
                field :scientific_name, !types.String
              end

            GenusType =
              GraphQL::ObjectType.define do
                name "Genus"
                field :species, !types[SpeciesType]
              end

            FamilyType =
              GraphQL::ObjectType.define do
                name "Family"
                field :genera, !types[GenusType]
                field :species, !types[SpeciesType]
              end

            QueryType =
              GraphQL::ObjectType.define do
                name "Query"
                field :some_dragonflies,
                      !types[Types::SpeciesType],
                      description: "A list of some of the dragonflies" do
                  resolve lambda { |_obj, _args, _ctx| Species.all }
                end

                field :families, !types[Types::FamilyType], description: "A list of families"

                field :family, Types::FamilyType, description: "A specific family" do
                  argument :name, !types.String
                end

                def family(name:)
                  ::Family.find_by!(name: name)
                end
              end
          end

          module Mutations
            CreateSpeciesResult =
              GraphQL::ObjectType.define do
                name "CreateSpeciesResult"
                field :species, !Types::SpeciesType
              end

            MutationType =
              GraphQL::ObjectType.define do
                name "Mutation"
                field :createSpecies, CreateSpeciesResult do
                  argument :genus, !types.String
                  argument :species, !types.String

                  resolve lambda { |_, args, _|
                            genus = Genus.find_by!(name: args[:genus])
                            species = genus.species.new(name: args[:species])
                            OpenStruct.new(species: species) if species.save
                          }
                end
              end
          end

          TestAppSchema =
            GraphQL::Schema.define do
              # This tracer should be added by the probe
              # tracer(GraphQL::Tracing::ActiveSupportNotificationsTracing)
              mutation(Mutations::MutationType)
              query(Types::QueryType)
            end
        else
          module Types
            class BaseObject < GraphQL::Schema::Object
            end
            class SpeciesType < BaseObject
              field :name, String, null: false
              field :common_name, String, null: false
              field :scientific_name, String, null: false
            end

            class GenusType < BaseObject
              field :species, [SpeciesType], null: false
            end

            class FamilyType < BaseObject
              field :genera, [GenusType], null: false
              field :species, [SpeciesType], null: false
            end

            class QueryType < BaseObject
              field :some_dragonflies,
                    [Types::SpeciesType],
                    null: false,
                    description: "A list of some of the dragonflies"

              field :families, [Types::FamilyType], null: false, description: "A list of families"

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

          module Mutations
            class BaseMutation < GraphQL::Schema::Mutation
              # Add your custom classes if you have them:
              # This is used for generating payload types
              object_class Types::BaseObject
              # This is used for return fields on the mutation's payload
              # field_class Types::BaseField
              # This is used for generating the `input: { ... }` object type
              # input_object_class Types::BaseInputObject
            end

            class CreateSpecies < BaseMutation
              null true

              argument :genus, String, required: true
              argument :species, String, required: true

              field :species, Types::SpeciesType, null: true
              field :errors, [String], null: false

              def resolve(genus:, species:)
                genus = Genus.find_by!(name: genus)
                species = genus.species.new(name: species)
                if species.save
                  # Successful creation, return the created object with no errors
                  { species: species, errors: [] }
                else
                  # Failed save, return the errors to the client
                  { species: nil, errors: species.errors.full_messages }
                end
              end
            end
          end

          class Types::MutationType < Types::BaseObject
            field :create_species, mutation: Mutations::CreateSpecies
          end

          class TestAppSchema < GraphQL::Schema
            # tracer(GraphQL::Tracing::ActiveSupportNotificationsTracing)

            mutation(Types::MutationType)
            query(Types::QueryType)
          end

          if defined?(GraphQL::Execution::Interpreter)
            # Uses the new GraphQL::Execution::Interpreter, which changes the order of some
            # events. This is available under graphql >= 1.9 and (as currently documented)
            # will eventually become the new default interpreter.
            class InterpreterSchema < GraphQL::Schema
              use GraphQL::Execution::Interpreter
              use GraphQL::Analysis::AST if defined?(GraphQL::Analysis::AST)

              mutation(Types::MutationType)
              query(Types::QueryType)
            end
          end
        end
      RUBY

      TestApp.current_schema = TestApp.const_get(schema_locator)

      @original_env = ENV.to_hash
      set_agent_env
      Skylight.probe("graphql")
      Skylight.start!

      stub_const("ApplicationRecord", Class.new(ActiveRecord::Base) { self.abstract_class = true })

      stub_const(
        "Family",
        Class.new(ApplicationRecord) do
          has_many :genera
          has_many :species, through: :genera
        end
      )

      stub_const(
        "Genus",
        Class.new(ApplicationRecord) do
          has_many :species
          belongs_to :family
        end
      )

      stub_const(
        "Species",
        Class.new(ApplicationRecord) do
          belongs_to :genus
          has_one :family, through: :genus

          def scientific_name
            "#{genus.name} #{name}"
          end
        end
      )

      seed_db

      stub_const(
        "MyApp",
        Class.new do
          def call(env)
            request = Rack::Request.new(env)

            params = request.params.with_indifferent_access
            variables = params[:variables]

            context = {
              skylight_endpoint: params[:manual_operation_name]
              # Query context goes here, for example:
              # current_user: current_user,
            }

            result =
              if params[:queries]
                formatted_queries =
                  params[:queries].map.with_index do |q, i|
                    {
                      query: q,
                      variables: variables,
                      context:
                        context.merge(
                          {}.tap do |h|
                            h[:skylight_endpoint] = "query-#{i}" if params[:manual_operation_name] == "indexed"
                          end
                        )
                    }
                  end

                TestApp.current_schema.multiplex(formatted_queries)
              else
                TestApp.current_schema.execute(
                  params[:query],
                  variables: variables,
                  context: context,
                  operation_name: params[:operation_name]
                )
              end

            # Normally Rails would set this as content_type, but this app doesn't
            # use Rails controllers.
            Skylight.trace.segment = "json"
            [200, {}, result]
          end
        end
      )
    end

    after :each do
      ENV.replace(@original_env)

      Skylight.stop!
    end

    let :app do
      Rack::Builder.new do
        use Skylight::Middleware
        run MyApp.new
      end
    end

    context "with agent", :http, :agent do
      shared_examples_for(:graphql_instrumentation) do
        before :each do
          stub_config_validation
          stub_session_request
        end

        def make_graphql_request(query:, variables: {}, **params)
          call env("/", method: :POST, params: { query: query, variables: variables, **params })
        end

        # Handles expected analysis events for legacy style (GraphQL 1.7.0-1.9.x)
        # and new interpreter style (GraphQL >= 1.9.x when using GraphQL::Execution::Interpreter).
        def expected_analysis_events(query_count = 1)
          events = [%w[app.graphql graphql.lex], %w[app.graphql graphql.parse], %w[app.graphql graphql.validate]].freeze

          analyze_event = %w[app.graphql graphql.analyze_query]
          event_style = TestApp.graphql17? ? :inline : expectation_event_style
          case event_style
          when :grouped
            events.cycle(query_count).to_a.tap { |a| a.concat([analyze_event].cycle(query_count).to_a) }
          when :inline
            [*events, analyze_event].cycle(query_count)
          else
            raise "Unexpected expectation_event_style: #{event_style}"
          end.to_a
        end

        let(:query_inner) { "#{TestApp.format_field_name("someDragonflies")} { name }" }

        context "with single queries" do
          it "successfully calls into graphql with anonymous queries" do
            make_graphql_request(query: "query { #{query_inner} }")

            server.wait resource: "/report"

            batch = server.reports[0]
            expect(batch).to_not be nil
            expect(batch.endpoints.count).to eq(1)
            endpoint = batch.endpoints[0]

            expect(endpoint.name).to eq("graphql:[anonymous]<sk-segment>json</sk-segment>")
            expect(endpoint.traces.count).to eq(1)
            trace = endpoint.traces[0]

            data = trace.filter_spans.map { |s| [s.event.category, s.event.title] }

            query_name = "[anonymous]"
            expect(data).to eq(
              [
                ["app.rack.request", nil],
                %w[app.graphql graphql.execute_multiplex],
                *expected_analysis_events,
                ["app.graphql", "graphql.execute_query: #{query_name}"],
                ["app.graphql", "graphql.execute_query_lazy: #{query_name}"]
              ]
            )
          end

          it "successfully calls into graphql with manually-named anonymous queries" do
            query_name = "FauxNamedQuery"
            make_graphql_request(query: "query { #{query_inner} }", manual_operation_name: query_name)

            server.wait resource: "/report"

            batch = server.reports[0]
            expect(batch).to_not be nil
            expect(batch.endpoints.count).to eq(1)
            endpoint = batch.endpoints[0]

            expect(endpoint.name).to eq("graphql:FauxNamedQuery<sk-segment>json</sk-segment>")
            expect(endpoint.traces.count).to eq(1)
            trace = endpoint.traces[0]

            data = trace.filter_spans.map { |s| [s.event.category, s.event.title] }

            expect(data).to eq(
              [
                ["app.rack.request", nil],
                %w[app.graphql graphql.execute_multiplex],
                *expected_analysis_events,
                ["app.graphql", "graphql.execute_query: #{query_name}"],
                ["db.sql.query", "SELECT FROM species"],
                ["db.active_record.instantiation", "Species Instantiation"],
                ["app.graphql", "graphql.execute_query_lazy: #{query_name}"]
              ]
            )
          end

          it "successfully calls into graphql with named queries" do
            call env(
                   "/test",
                   method: :POST,
                   params: {
                     operationName: "Anisoptera", # This is optional if there is only one query node
                     query: "query Anisoptera { #{query_inner} }"
                   }
                 )

            server.wait resource: "/report"

            batch = server.reports[0]
            expect(batch).to_not be nil
            expect(batch.endpoints.count).to eq(1)
            endpoint = batch.endpoints[0]

            expect(endpoint.name).to eq("graphql:Anisoptera<sk-segment>json</sk-segment>")
            expect(endpoint.traces.count).to eq(1)
            trace = endpoint.traces[0]

            data = trace.filter_spans.map { |s| [s.event.category, s.event.title] }

            query_name = "Anisoptera"
            expect(data).to eq(
              [
                ["app.rack.request", nil],
                %w[app.graphql graphql.execute_multiplex],
                *expected_analysis_events,
                ["app.graphql", "graphql.execute_query: #{query_name}"],
                ["db.sql.query", "SELECT FROM species"],
                ["db.active_record.instantiation", "Species Instantiation"],
                ["app.graphql", "graphql.execute_query_lazy: #{query_name}"]
              ]
            )
          end
        end

        context "with multiplex queries" do
          it "successfully calls into graphql with anonymous queries" do
            queries = ["query { #{query_inner} }"].cycle.take(3)

            call env("/test", method: :POST, params: { queries: queries })

            server.wait resource: "/report"

            batch = server.reports[0]
            expect(batch).to_not be nil
            expect(batch.endpoints.count).to eq(1)
            endpoint = batch.endpoints[0]

            expect(endpoint.name).to eq("graphql:[anonymous]<sk-segment>json</sk-segment>")
            expect(endpoint.traces.count).to eq(1)
            trace = endpoint.traces[0]

            data = trace.filter_spans.map { |s| [s.event.category, s.event.title] }

            query_name = "[anonymous]"
            expect(data).to eq(
              [
                ["app.rack.request", nil],
                %w[app.graphql graphql.execute_multiplex],
                *expected_analysis_events(3),
                ["app.graphql", "graphql.execute_query: #{query_name}"],
                ["app.graphql", "graphql.execute_query: #{query_name}"],
                ["app.graphql", "graphql.execute_query: #{query_name}"],
                %w[app.graphql graphql.execute_query_lazy.multiplex]
              ]
            )
          end

          it "successfully calls into graphql with manually-named anonymous queries" do
            queries = ["query { #{query_inner} }"].cycle.take(3)

            call env("/test", method: :POST, params: { queries: queries, manual_operation_name: :indexed })

            server.wait resource: "/report"

            batch = server.reports[0]
            expect(batch).to_not be nil
            expect(batch.endpoints.count).to eq(1)
            endpoint = batch.endpoints[0]

            expect(endpoint.name).to eq("graphql:query-0+query-1+query-2<sk-segment>json</sk-segment>")
            expect(endpoint.traces.count).to eq(1)
            trace = endpoint.traces[0]

            data = trace.filter_spans.map { |s| [s.event.category, s.event.title] }

            expect(data).to eq(
              [
                ["app.rack.request", nil],
                %w[app.graphql graphql.execute_multiplex],
                *expected_analysis_events(3),
                *%w[query-0 query-1 query-2].map do |qn|
                  [
                    ["app.graphql", "graphql.execute_query: #{qn}"],
                    ["db.sql.query", "SELECT FROM species"],
                    ["db.active_record.instantiation", "Species Instantiation"]
                  ]
                end.flatten(1),
                %w[app.graphql graphql.execute_query_lazy.multiplex]
              ]
            )
          end

          it "successfully calls into graphql with named and anonymous queries" do
            queries = ["query { #{query_inner} }"].cycle.take(3)
            queries.push("query myFavoriteDragonflies { #{query_inner} }")

            call env("/test", method: :POST, params: { queries: queries })

            server.wait resource: "/report"

            batch = server.reports[0]
            expect(batch).to_not be nil
            expect(batch.endpoints.count).to eq(1)
            endpoint = batch.endpoints[0]

            expect(endpoint.name).to eq("graphql:[anonymous]+myFavoriteDragonflies<sk-segment>json</sk-segment>")
            expect(endpoint.traces.count).to eq(1)
            trace = endpoint.traces[0]

            data = trace.filter_spans.map { |s| [s.event.category, s.event.title] }

            query_name = "[anonymous]"
            expect(data).to eq(
              [
                ["app.rack.request", nil],
                %w[app.graphql graphql.execute_multiplex],
                *expected_analysis_events(4),
                ["app.graphql", "graphql.execute_query: #{query_name}"],
                ["app.graphql", "graphql.execute_query: #{query_name}"],
                ["app.graphql", "graphql.execute_query: #{query_name}"],
                ["app.graphql", "graphql.execute_query: myFavoriteDragonflies"],
                ["db.sql.query", "SELECT FROM species"],
                ["db.active_record.instantiation", "Species Instantiation"],
                %w[app.graphql graphql.execute_query_lazy.multiplex]
              ]
            )
          end

          it "successfully calls into graphql with named queries" do
            queries = [
              "query myFavoriteDragonflies { #{query_inner} }",
              "query kindOfOkayDragonflies { #{query_inner} }"
            ]

            call env("/test", method: :POST, params: { queries: queries })

            server.wait resource: "/report"

            batch = server.reports[0]
            expect(batch).to_not be nil
            expect(batch.endpoints.count).to eq(1)
            endpoint = batch.endpoints[0]

            expect(endpoint.name).to eq(
              "graphql:kindOfOkayDragonflies+myFavoriteDragonflies<sk-segment>json</sk-segment>"
            )
            expect(endpoint.traces.count).to eq(1)
            trace = endpoint.traces[0]

            data = trace.filter_spans.map { |s| [s.event.category, s.event.title] }

            expect(data).to eq(
              [
                ["app.rack.request", nil],
                %w[app.graphql graphql.execute_multiplex],
                *expected_analysis_events(2),
                ["app.graphql", "graphql.execute_query: myFavoriteDragonflies"],
                ["db.sql.query", "SELECT FROM species"],
                ["db.active_record.instantiation", "Species Instantiation"],
                ["app.graphql", "graphql.execute_query: kindOfOkayDragonflies"],
                ["db.sql.query", "SELECT FROM species"],
                ["db.active_record.instantiation", "Species Instantiation"],
                %w[app.graphql graphql.execute_query_lazy.multiplex]
              ]
            )
          end

          it "reports a compound segment" do
            queries = ["query myFavoriteDragonflies { #{query_inner} }", "query kindOfOkayDragonflies { missingField }"]

            res = call env("/test", method: :POST, params: { queries: queries })

            expect(res.last.to_h.key?("errors")).to eq(true)

            server.wait resource: "/report"

            batch = server.reports[0]
            expect(batch).to_not be nil
            expect(batch.endpoints.count).to eq(1)
            endpoint = batch.endpoints[0]

            expect(endpoint.name).to eq(
              "graphql:kindOfOkayDragonflies+myFavoriteDragonflies<sk-segment>json+error</sk-segment>"
            )
            expect(endpoint.traces.count).to eq(1)
            trace = endpoint.traces[0]

            data = trace.filter_spans.map { |s| [s.event.category, s.event.title] }

            expect(data).to eq(
              [
                ["app.rack.request", nil],
                %w[app.graphql graphql.execute_multiplex],
                *expected_analysis_events(2)[0..-2],
                ["app.graphql", "graphql.execute_query: myFavoriteDragonflies"],
                ["db.sql.query", "SELECT FROM species"],
                ["db.active_record.instantiation", "Species Instantiation"],
                %w[app.graphql graphql.execute_query_lazy.multiplex]
              ]
            )
          end

          it "reports a compound error" do
            queries = ["query myFavoriteDragonflies { missingField }", "query kindOfOkayDragonflies { missingField }"]

            res = call env("/test", method: :POST, params: { queries: queries })

            expect(res.last.to_h.key?("errors")).to eq(true)

            server.wait resource: "/report"

            batch = server.reports[0]
            expect(batch).to_not be nil
            expect(batch.endpoints.count).to eq(1)
            endpoint = batch.endpoints[0]

            expect(endpoint.name).to eq(
              "graphql:kindOfOkayDragonflies+myFavoriteDragonflies<sk-segment>error</sk-segment>"
            )
            expect(endpoint.traces.count).to eq(1)
            trace = endpoint.traces[0]

            data = trace.filter_spans.map { |s| [s.event.category, s.event.title] }

            expect(data).to eq(
              [
                ["app.rack.request", nil],
                %w[app.graphql graphql.execute_multiplex],
                *expected_analysis_events(2).reject { |_, e| e["graphql.analyze"] },
                %w[app.graphql graphql.execute_query_lazy.multiplex]
              ]
            )
          end
        end

        let(:mutation_inner) { <<~GRAPHQL }
            createSpecies(genus: $genus, species: $species) {
              species { #{TestApp.format_field_name("scientificName")} }
            }
          GRAPHQL

        context "with single mutations" do
          let(:mutation_name) { "CreateSpeciesMutation" }

          it "successfully calls into graphql with anonymous mutations" do
            make_graphql_request(
              query: "mutation #{mutation_name}($genus: String!, $species: String!) { #{mutation_inner} }",
              variables: {
                genus: "Ischnura",
                species: "damula"
              }
            )

            server.wait resource: "/report"

            batch = server.reports[0]
            expect(batch).to_not be nil
            expect(batch.endpoints.count).to eq(1)
            endpoint = batch.endpoints[0]

            expect(endpoint.name).to eq("graphql:#{mutation_name}<sk-segment>json</sk-segment>")
            expect(endpoint.traces.count).to eq(1)
            trace = endpoint.traces[0]

            data = trace.filter_spans.map { |s| [s.event.category, s.event.title] }

            expect(data).to eq(
              [
                ["app.rack.request", nil],
                %w[app.graphql graphql.execute_multiplex],
                *expected_analysis_events,
                ["app.graphql", "graphql.execute_query: #{mutation_name}"],
                ["db.sql.query", "SELECT FROM genera"],
                ["db.active_record.instantiation", "Genus Instantiation"],
                ["db.sql.query", active_record_transaction_title],
                ["db.sql.query", "INSERT INTO species"],
                ["db.sql.query", active_record_transaction_title],
                ["app.graphql", "graphql.execute_query_lazy: #{mutation_name}"]
              ]
            )
          end
        end
      end

      configs = []

      configs << { schema: :InterpreterSchema, expectation_event_style: :inline } if test_interpreter_schema?

      # GraphQL::Execution::Interpreter became the default as of 1.12, so we do not need to
      # test an additional schema for versions >= 1.12.
      if Gem::Version.new(GraphQL::VERSION) < Gem::Version.new("1.12")
        configs << { schema: :TestAppSchema, expectation_event_style: :grouped }
      end

      configs.each do |config|
        context config[:schema].to_s do
          let(:expectation_event_style) { config[:expectation_event_style] }
          it_behaves_like :graphql_instrumentation do
            let(:schema_locator) { config[:schema] }
          end
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
