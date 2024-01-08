require "spec_helper"

enable = false
begin
  require "active_record"
  enable = true
rescue LoadError
  puts "[INFO] Skipping ActiveRecord integration specs"
end

if enable
  describe "SQL partial integration", :http, :agent do
    before :each do
      start!
      Skylight.trace("endpoint", "app.rack.request", nil, meta: {}, component: :web)
    end

    after :each do
      Skylight.stop!
    end

    def handle_query(opts)
      ActiveSupport::Notifications.instrument("sql.active_record", opts)
      current_trace.submit

      server.wait resource: "/report"
      trace = server.reports.dig(0, :endpoints, 0, :traces, 0)

      span = trace.spans.find { |s| s.event.category == "db.sql.query" }
      expect(span).to_not be_nil, "created a span"

      [span.event.category, span.event.title, span.event.description]
    end

    it "Pulls out binds" do
      cat, title, desc = handle_query(name: "Foo Load", sql: "select * from foo where id = $1")

      expect(cat).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM foo")
      expect(desc).to eq("select * from foo where id = ?")
    end

    it "Handles queries without a title" do
      sql = "SELECT * from foo"

      cat, title, desc = handle_query(name: nil, sql: sql)

      expect(cat).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM foo")
      expect(desc).to eq(sql)
    end

    it "Handles Rails-style insertions" do
      sql = <<~SQL
        INSERT INTO "agent_errors" ("body", "created_at", "hostname", "reason") VALUES ($1, $2, $3, $4)
        RETURNING "id"
      SQL

      cat, title, desc = handle_query(name: "SQL", sql: sql)

      expect(cat).to eq("db.sql.query")
      expect(title).to eq("INSERT INTO agent_errors")
      expect(desc).to eq(<<~SQL.strip)
        INSERT INTO "agent_errors" ("body", "created_at", "hostname", "reason") VALUES (?, ?, ?, ?)
        RETURNING "id"
      SQL
    end

    it "Determines embedded binds" do
      cat, title, desc = handle_query(name: "Foo Load", sql: "select * from foo where id = 1")

      expect(cat).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM foo")
      expect(desc).to eq("select * from foo where id = ?")
    end

    it "handles some precomputed binds" do
      sql = <<~SQL
        INSERT INTO "agent_errors" ("body", "created_at", "value", "hostname", "reason")
        VALUES ($1, $2, NULL, $3, $4) RETURNING "id"
      SQL
      extracted = <<~SQL
        INSERT INTO "agent_errors" ("body", "created_at", "value", "hostname", "reason")
        VALUES (?, ?, ?, ?, ?) RETURNING "id"
      SQL

      cat, title, desc = handle_query(name: "SQL", sql: sql)

      expect(cat).to eq("db.sql.query")
      expect(title).to eq("INSERT INTO agent_errors")
      expect(desc).to eq(extracted.strip)
    end

    context "with logging" do
      let :tmpdir do
        Dir.mktmpdir
      end

      let(:log_sql_parse_errors) { true }

      def test_config_values
        super.merge(
          log_level: "debug",
          native_log_file: "#{tmpdir}/native.log",
          log_sql_parse_errors: log_sql_parse_errors
        )
      end

      after :each do
        FileUtils.remove_entry_secure tmpdir
      end

      it "Produces an error if the SQL isn't parsable" do
        cat, title, desc = handle_query(name: "Foo Load", sql: "!!!")

        expect(cat).to eq("db.sql.query")
        expect(title).to eq("Foo Load")
        expect(desc).to eq(nil)

        expect(File.read("#{tmpdir}/native.log")).to include("Failed to extract binds")
      end

      context "with logging disabled" do
        let(:log_sql_parse_errors) { false }

        it "does not log" do
          cat, title, desc = handle_query(name: "Foo Load", sql: "!!!")

          expect(cat).to eq("db.sql.query")
          expect(title).to eq("Foo Load")
          expect(desc).to eq(nil)

          expect(File.read("#{tmpdir}/native.log")).to_not include("Failed to extract binds")
        end
      end
    end
  end

  describe "SQL full integration", :http, :agent, :active_record_async_probe do
    let(:users_migration) do
      base = ActiveRecord::Migration
      base = base::Current if defined?(base::Current)

      Class.new(base) do
        def self.up
          create_table :users, force: :cascade do |t|
            t.string "name", null: false
            t.datetime "created_at", precision: 6, null: false
            t.datetime "updated_at", precision: 6, null: false
          end
        end

        def self.down
          drop_table :users
        end
      end
    end

    let(:executor) { :global_thread_pool }

    around :each do |example|
      original_executor = ActiveRecord.async_query_executor
      ActiveRecord.async_query_executor = executor

      # Use a database file to avoid threading issues
      with_sqlite(migration: users_migration, database: "sql-test.sqlite") { example.run }
    ensure
      ActiveRecord.async_query_executor = original_executor
    end

    before :each do
      stub_const("User", Class.new(ActiveRecord::Base))

      User.find_or_create_by!(name: "Tester")

      start!
      Skylight.trace("endpoint", "app.rack.request", nil, meta: {}, component: :web)
    end

    after :each do
      Skylight.stop!
    end

    it "works for load_async when running async" do
      # This is a very imperfect way to check that we're actually executing this async
      expect_any_instance_of(ActiveRecord::FutureResult::EventBuffer).to(
        receive(:instrument).at_least(:once).and_call_original)

      users = User.all.load_async

      # This sleep before the `to_a` ensures that it happens async
      sleep 1
      users.to_a

      current_trace.submit

      server.wait resource: "/report"
      trace = server.reports.dig(0, :endpoints, 0, :traces, 0)

      future_span = trace.spans.find { |s| s.event.category == "db.future_result" }
      expect(future_span).to_not be_nil, "created a future span"

      expect(future_span.event.category).to eq("db.future_result")
      expect(future_span.event.title).to eq("Async User Load")
      expect(future_span.event.description).to be_nil

      query_span = trace.spans.find { |s| s.event.category == "db.sql.query" }
      expect(query_span).to_not be_nil, "created a query span"
      expect(query_span.parent).to eq(trace.spans.index(future_span)), "child of future span"

      expect(query_span.event.category).to eq("db.sql.query")
      expect(query_span.event.title).to eq("SELECT FROM users")
      expect(query_span.event.description).to eq("SELECT \"users\".* FROM \"users\"")
    end

    it "works for load_async when not actually async" do
      # This is a very imperfect way to check that we're not executing this async
      expect_any_instance_of(ActiveRecord::FutureResult::EventBuffer).not_to receive(:instrument)

      User.all.load_async.to_a

      current_trace.submit

      server.wait resource: "/report"
      trace = server.reports.dig(0, :endpoints, 0, :traces, 0)

      future_span = trace.spans.find { |s| s.event.category == "db.future_result" }
      expect(future_span).to_not be_nil, "created a future span"

      expect(future_span.event.category).to eq("db.future_result")
      expect(future_span.event.title).to eq("Async User Load")
      expect(future_span.event.description).to be_nil

      query_span = trace.spans.find { |s| s.event.category == "db.sql.query" }
      expect(query_span).to_not be_nil, "created a query span"
      expect(query_span.parent).to eq(trace.spans.index(future_span)), "child of future span"

      expect(query_span.event.category).to eq("db.sql.query")
      expect(query_span.event.title).to eq("SELECT FROM users")
      expect(query_span.event.description).to eq("SELECT \"users\".* FROM \"users\"")
    end

    it "works for load_async with errors" do
      allow_any_instance_of(ActiveRecord::ConnectionAdapters::SQLite3Adapter).to receive(
        :internal_exec_query
      ).and_raise("AAAHHH")

      users = User.all.load_async
      sleep 1
      expect { users.to_a }.to raise_error("AAAHHH")

      current_trace.submit

      server.wait resource: "/report"
      trace = server.reports.dig(0, :endpoints, 0, :traces, 0)

      future_span = trace.spans.find { |s| s.event.category == "db.future_result" }
      expect(future_span).to_not be_nil, "created a future span"

      expect(future_span.event.category).to eq("db.future_result")
      expect(future_span.event.title).to eq("Async User Load")
      expect(future_span.event.description).to be_nil

      query_span = trace.spans.find { |s| s.event.category == "db.sql.query" }

      expect(query_span).to be_nil, "did not create a query span"
    end

    context "without executor" do
      let(:executor) { nil }

      it "works" do
        users = User.all.load_async
        sleep 1
        users.to_a

        current_trace.submit

        server.wait resource: "/report"
        trace = server.reports.dig(0, :endpoints, 0, :traces, 0)

        future_span = trace.spans.find { |s| s.event.category == "db.future_result" }
        expect(future_span).to be_nil, "did not create a future span"

        query_span = trace.spans.find { |s| s.event.category == "db.sql.query" }
        expect(query_span).to_not be_nil, "created a query span"

        expect(query_span.event.category).to eq("db.sql.query")
        expect(query_span.event.title).to eq("SELECT FROM users")
        expect(query_span.event.description).to eq("SELECT \"users\".* FROM \"users\"")
      end
    end
  end
end
