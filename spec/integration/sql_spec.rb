require "spec_helper"

if Skylight.native?
  describe "Initialization integration", :http do
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
      cat, title, desc =
        handle_query(name: "Foo Load", sql: "select * from foo where id = $1")

      expect(cat).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM foo")
      expect(desc).to eq("select * from foo where id = ?")
    end

    it "Handles queries without a title" do
      sql = "SELECT * from foo"

      cat, title, desc =
        handle_query(name: nil, sql: sql)

      expect(cat).to eq("db.sql.query")
      expect(title).to eq("SELECT FROM foo")
      expect(desc).to eq(sql)
    end

    it "Handles Rails-style insertions" do
      sql = <<~SQL
        INSERT INTO "agent_errors" ("body", "created_at", "hostname", "reason") VALUES ($1, $2, $3, $4)
        RETURNING "id"
      SQL

      cat, title, desc =
        handle_query(name: "SQL", sql: sql)

      expect(cat).to eq("db.sql.query")
      expect(title).to eq("INSERT INTO agent_errors")
      expect(desc).to eq(<<~SQL.strip)
        INSERT INTO "agent_errors" ("body", "created_at", "hostname", "reason") VALUES (?, ?, ?, ?)
        RETURNING "id"
      SQL
    end

    it "Determines embedded binds" do
      cat, title, desc =
        handle_query(name: "Foo Load", sql: "select * from foo where id = 1")

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

      cat, title, desc =
        handle_query(name: "SQL", sql: sql)

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
        cat, title, desc =
          handle_query(name: "Foo Load", sql: "!!!")

        expect(cat).to eq("db.sql.query")
        expect(title).to eq("Foo Load")
        expect(desc).to eq(nil)

        expect(File.read("#{tmpdir}/native.log")).to include("Failed to extract binds")
      end

      context "with logging disabled" do
        let(:log_sql_parse_errors) { false }

        it "does not log" do
          cat, title, desc =
            handle_query(name: "Foo Load", sql: "!!!")

          expect(cat).to eq("db.sql.query")
          expect(title).to eq("Foo Load")
          expect(desc).to eq(nil)

          expect(File.read("#{tmpdir}/native.log")).to_not include("Failed to extract binds")
        end
      end
    end
  end
end

