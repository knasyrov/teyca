#
# CREATE TABLE "operations" (
#   id INTEGER not null constraint operation_pk primary key autoincrement,
#   user_id INT not null references "users",
#   cashback numeric not null,
#   cashback_percent numeric not null,
#   discount numeric not null,
#   discount_percent numeric not null,
#   write_off numeric,
#   check_summ numeric not null,
#   done boolean,
#   allowed_write_off numeric
# )
#
class Operation < Sequel::Model
  many_to_one :user

  def to_h
    values.map {|k, e| e.is_a?(BigDecimal) ? [k, e.to_f.to_s] : [k, e]}.to_h
  end
end
