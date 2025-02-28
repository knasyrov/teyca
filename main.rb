require 'sequel'
require 'sqlite3'

DB = Sequel.connect('sqlite://test.db')
Dir["#{File.dirname(__FILE__)}/models/**/*.rb"].each {|file| require file }

require 'sinatra'
require 'sinatra/json'

require 'bundler'
Bundler.require

before do
  request.body.rewind
  @request_payload = JSON.parse(request.body.read, symbolize_names: true)
end

get '/' do
  u = User.all.map(&:name).join(' - ')
  #'Hello world!'
  u
end

get '/users' do
  json(User.map(&:to_hash))
end

get '/products' do
  json(Product.map(&:to_hash))
end

get '/templates' do
  json(Template.map(&:to_hash))
end

get '/operations' do
  json(Operation.map(&:to_hash))
end

post '/operation' do
  #puts params.inspect
  #puts @request_payload.inspect
  #puts @request_payload[:user_id]
  user_id = @request_payload[:user_id]
  user = User[user_id]
  if user
    puts user.template.inspect
    puts user.inspect
    positions =  @request_payload[:positions]
    positions.each_with_index do |pos, idx|
      product = Product[pos[:id]]
      puts "#{idx} - #{product.inspect}"
    end
  end
=begin
  o = Operation.new
  o.user_id = User.last.id
  o.cashback = 0
  o.cashback_percent = 0
  o.discount = 0
  o.discount_percent = 0
  #o.write_off
  o.check_summ = 0
  #o.done
  o.save
  json({
    id: o.id,
    status: o.done,
    user: user.values,
    total: 0,
    positions: []
  })
=end
end
=begin
cashback numeric not null,
  cashback_percent numeric not null,
  discount numeric not null,
  discount_percent numeric not null,
  write_off numeric,
  check_summ numeric not null,
  done boolean,
  allowed_write_off
=end

error 404 do
  { error: 'Resource not found' }.to_json
end