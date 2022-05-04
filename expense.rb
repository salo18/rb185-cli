#! /usr/bin/env ruby

require "pg"
require "io/console"


class ExpenseData
  def initialize
    @connection = PG.connect(dbname: "expenses")

    setup_schema
  end

  def add_expense(amount, memo)
    date = Date.today

    sql = "INSERT INTO expenses (amount, memo, created_on) VALUES ($1, $2, $3)"

    if amount != nil && memo != nil
      @connection.exec_params(sql, [amount, memo, date])
    else
      puts "You must provide an amount and memo"
    end
  end

  def list_expenses
    result = @connection.exec "SELECT * FROM expenses ORDER BY created_on ASC"

    display_count(result)
    display_expenses(result) if result.ntuples > 0
  end

  def search_expenses(query)
    sql = "SELECT * FROM expenses WHERE memo ILIKE $1"
    result = @connection.exec_params(sql, ["%#{query}%"])
    display_count(result)
    display_expenses(result) if result.ntuples > 0
  end

  def delete_expense(idx)
    # # check if id is available
    # id_check = "SELECT id FROM expenses;"
    # id_result = @connection.exec(id_check).to_a.map {|k, v| k.to_a }.flatten.map {|x| x.to_i}.include?(idx.to_i)

    # if id_result
    #   # get the query before the row is deleted
    #   check = "SELECT * FROM expenses WHERE id = $1"
    #   check_result = @connection.exec_params(check, [idx])

    #   sql = "DELETE FROM expenses WHERE id = $1"
    #   @connection.exec_params(sql, [idx])
    #   puts "The following expense has been deleted"
    #   display_expenses(check_result)
    # else
    #   puts "There is no expense with the id '#{idx}'."
    # end

    sql = "SELECT * FROM expenses WHERE id = $1"
    result = @connection.exec_params(sql, [idx])

    if result.ntuples == 1
      sql = "DELETE FROM expenses WHERE id=$1"
      @connection.exec_params(sql, [idx])

      puts "The following expense has been deleted:"
      display_expenses(result)
    else
      puts "There is no expense with the id '#{idx}'."
    end

  end

  def delete_all_expenses
    puts "This will remove all expenses. Are you sure? (y/n)"
    answer = STDIN.getch
    if answer.downcase == "y"
      @connection.exec("DELETE FROM expenses")
      puts "All expenses have been deleted."
    end
  end

  private

  def display_expenses(expenses)
    expenses.each do |row|
      columns = [ row["id"].rjust(3),
                  row["created_on"].rjust(10),
                  row["amount"].rjust(12),
                  row["memo"] ]

      puts columns.join(" | ")
    end

    puts "-" * 50
    sum = expenses.field_values("amount").map(&:to_f).inject(:+).round(2)
    puts "Total #{sum.to_s.rjust(25)}"
  end

  def display_count(expenses)
    count = expenses.ntuples
    if count == 0
      puts "There are no expenses yet."
    else
      puts "There are #{count} expense#{"s" if count > 1 }."
    end
  end

  def setup_schema
    result = @connection.exec <<~SQL
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'expenses';
    SQL

    if result[0]["count"] == "0"
      @connection.exec <<~SQL
        CREATE TABLE expenses (
          id serial PRIMARY KEY,
          amount numeric(6,2) NOT NULL CHECK (amount >= 0.01),
          memo text NOT NULL,
          created_on date NOT NULL
        );
      SQL
    end
  end

end

class CLI
  def initialize
    @app = ExpenseData.new
  end

  def run(arr)
    command = arr[0]

    if command == "list"
      @app.list_expenses
    elsif command == "add"
      @app.add_expense(arr[1], arr[2])
    elsif command == "search"
      @app.search_expenses(arr[1])
    elsif command == "delete"
      @app.delete_expense(arr[1])
    elsif command == "clear"
      @app.delete_all_expenses
    else
      display_help
    end
  end

  def display_help
    puts <<~HELP
      An expense recording system

      Commands:

      add AMOUNT MEMO [DATE] - record a new expense
      clear - delete all expenses
      list - list all expenses
      delete NUMBER - remove expense with id NUMBER
      search QUERY - list expenses with a matching memo field
    HELP
  end

end

CLI.new.run(ARGV)
