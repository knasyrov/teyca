#
# CREATE TABLE "products" (
#   id INTEGER not null constraint table_name_pk primary key autoincrement,
#   name varchar(255) not null,
#   type varchar(255),
#   value varchar(255)
# )

class Product < Sequel::Model
end