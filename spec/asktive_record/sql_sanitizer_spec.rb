# frozen_string_literal: true

require "spec_helper"
require "asktive_record/sql_sanitizer"
require "asktive_record/error"

RSpec.describe AsktiveRecord::SqlSanitizer do
  describe ".sanitize!" do
    context "with valid SELECT queries" do
      it "passes through a simple SELECT" do
        sql = "SELECT * FROM users"
        expect(described_class.sanitize!(sql)).to eq("SELECT * FROM users")
      end

      it "passes through SELECT with WHERE clause" do
        sql = "SELECT * FROM users WHERE id = 1"
        expect(described_class.sanitize!(sql)).to eq(sql)
      end

      it "passes through SELECT with JOIN" do
        sql = "SELECT u.*, p.name FROM users u JOIN profiles p ON u.id = p.user_id"
        expect(described_class.sanitize!(sql)).to eq(sql)
      end

      it "passes through SELECT with ORDER BY and LIMIT" do
        sql = "SELECT * FROM users ORDER BY created_at DESC LIMIT 5"
        expect(described_class.sanitize!(sql)).to eq(sql)
      end

      it "passes through SELECT with GROUP BY and HAVING" do
        sql = "SELECT status, COUNT(*) as cnt FROM orders GROUP BY status HAVING cnt > 5"
        expect(described_class.sanitize!(sql)).to eq(sql)
      end

      it "strips trailing semicolons" do
        sql = "SELECT * FROM users;"
        expect(described_class.sanitize!(sql)).to eq("SELECT * FROM users")
      end

      it "strips trailing semicolons with spaces" do
        sql = "SELECT * FROM users;  "
        expect(described_class.sanitize!(sql)).to eq("SELECT * FROM users")
      end

      it "is case-insensitive for SELECT" do
        sql = "select * from users"
        expect(described_class.sanitize!(sql)).to eq(sql)
      end
    end

    context "with nil or empty input" do
      it "raises SanitizationError for nil SQL" do
        expect do
          described_class.sanitize!(nil)
        end.to raise_error(AsktiveRecord::SanitizationError, /cannot be nil or empty/)
      end

      it "raises SanitizationError for empty SQL" do
        expect do
          described_class.sanitize!("")
        end.to raise_error(AsktiveRecord::SanitizationError, /cannot be nil or empty/)
      end

      it "raises SanitizationError for whitespace-only SQL" do
        expect do
          described_class.sanitize!("   ")
        end.to raise_error(AsktiveRecord::SanitizationError, /cannot be nil or empty/)
      end
    end

    context "with non-SELECT queries" do
      it "rejects INSERT statements" do
        expect do
          described_class.sanitize!("INSERT INTO users (name) VALUES ('test')")
        end.to raise_error(AsktiveRecord::SanitizationError, /Only SELECT statements are allowed/)
      end

      it "rejects UPDATE statements" do
        expect do
          described_class.sanitize!("UPDATE users SET name = 'test'")
        end.to raise_error(AsktiveRecord::SanitizationError, /Only SELECT statements are allowed/)
      end

      it "rejects DELETE statements" do
        expect do
          described_class.sanitize!("DELETE FROM users WHERE id = 1")
        end.to raise_error(AsktiveRecord::SanitizationError, /Only SELECT statements are allowed/)
      end

      it "rejects DROP statements" do
        expect do
          described_class.sanitize!("DROP TABLE users")
        end.to raise_error(AsktiveRecord::SanitizationError, /Only SELECT statements are allowed/)
      end

      it "rejects ALTER statements" do
        expect do
          described_class.sanitize!("ALTER TABLE users ADD COLUMN age INT")
        end.to raise_error(AsktiveRecord::SanitizationError, /Only SELECT statements are allowed/)
      end

      it "rejects TRUNCATE statements" do
        expect do
          described_class.sanitize!("TRUNCATE TABLE users")
        end.to raise_error(AsktiveRecord::SanitizationError, /Only SELECT statements are allowed/)
      end
    end

    context "with allow_only_select: false" do
      it "still blocks dangerous keywords" do
        expect do
          described_class.sanitize!("DROP TABLE users", allow_only_select: false)
        end.to raise_error(AsktiveRecord::SanitizationError, /Dangerous SQL keyword/)
      end
    end

    context "with SQL injection patterns" do
      it "blocks semicolon-based injection" do
        expect do
          described_class.sanitize!("SELECT * FROM users; DROP TABLE users")
        end.to raise_error(AsktiveRecord::SanitizationError)
      end

      it "blocks SQL line comments" do
        expect do
          described_class.sanitize!("SELECT * FROM users -- WHERE admin = true")
        end.to raise_error(AsktiveRecord::SanitizationError)
      end

      it "blocks SQL block comments" do
        expect do
          described_class.sanitize!("SELECT * FROM users /* WHERE admin = true */")
        end.to raise_error(AsktiveRecord::SanitizationError)
      end

      it "blocks UNION-based injection" do
        expect do
          described_class.sanitize!("SELECT name FROM users UNION SELECT password FROM admin_users")
        end.to raise_error(AsktiveRecord::SanitizationError)
      end

      it "blocks INTO OUTFILE" do
        expect do
          described_class.sanitize!("SELECT * FROM users INTO OUTFILE '/tmp/data.csv'")
        end.to raise_error(AsktiveRecord::SanitizationError)
      end

      it "blocks INTO DUMPFILE" do
        expect do
          described_class.sanitize!("SELECT * FROM users INTO DUMPFILE '/tmp/data.bin'")
        end.to raise_error(AsktiveRecord::SanitizationError)
      end

      it "blocks SLEEP injection" do
        expect do
          described_class.sanitize!("SELECT * FROM users WHERE SLEEP(5)")
        end.to raise_error(AsktiveRecord::SanitizationError)
      end

      it "blocks BENCHMARK injection" do
        expect do
          described_class.sanitize!("SELECT BENCHMARK(1000000, SHA1('test')) FROM users")
        end.to raise_error(AsktiveRecord::SanitizationError)
      end

      it "blocks LOAD_FILE" do
        expect do
          described_class.sanitize!("SELECT LOAD_FILE('/etc/passwd')")
        end.to raise_error(AsktiveRecord::SanitizationError)
      end

      it "blocks WAITFOR DELAY (MSSQL)" do
        expect do
          described_class.sanitize!("SELECT * FROM users WAITFOR DELAY '0:0:5'")
        end.to raise_error(AsktiveRecord::SanitizationError)
      end

      it "blocks pg_sleep (PostgreSQL)" do
        expect do
          described_class.sanitize!("SELECT pg_sleep(5) FROM users")
        end.to raise_error(AsktiveRecord::SanitizationError)
      end
    end

    context "with quoted strings that contain keywords" do
      it "does not raise for SELECT with keyword-like string values" do
        sql = "SELECT * FROM users WHERE name = 'not a drop table'"
        # The keyword check strips string literals, so this should pass
        expect(described_class.sanitize!(sql)).to eq(sql)
      end
    end
  end
end
