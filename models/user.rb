#
# CREATE TABLE "users" (
#   id INTEGER not null constraint user_pk primary key autoincrement,
#   template_id INT not null constraint template_id references "templates",
#   name varchar(255) not null,
#   bonus numeric
# )
#
class User < Sequel::Model
  many_to_one :template

  def to_h
    values.map {|k, e| e.is_a?(BigDecimal) ? [k, e.to_f.to_s] : [k, e]}.to_h
  end
end