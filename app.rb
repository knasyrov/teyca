require 'bundler'
Bundler.require

require 'sinatra/json'
require "sinatra/namespace"

DB = Sequel.connect('sqlite://test.db')
Dir["#{File.dirname(__FILE__)}/models/**/*.rb"].each {|file| require file }

class App < Sinatra::Base
  POSITION_PARAMS_TO_SCRUB = [ :cashback, :amount ].freeze
  OPERATION_PARAMS_TO_SCRUB = [ :id, :done, :allowed_write_off ]

  configure do
    set :root, File.dirname(__FILE__)
    register Sinatra::Namespace
  end

  configure :development do
    register Sinatra::Reloader
  end

  error 404 do
    { error: 'Resource not found' }.to_json
  end

  namespace '/admin' do
    before do
      status :ok
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
  end

  post '/submit' do
    content_type :json
    begin
      request.body.rewind
      request_payload = JSON.parse(request.body.read, symbolize_names: true)

      operation = Operation[request_payload[:operation_id]]
      raise 'Operation not found' if operation.nil?
      raise 'Operation already complete' if operation.done

      user = User[request_payload.dig(:user, :id)]
      raise 'User no found' if user.nil?

      raise "Not enough points to write off!" if user.bonus < request_payload[:write_off]

      DB.transaction do
        operation.write_off = request_payload[:write_off]
        operation.check_summ -= request_payload[:write_off]
        operation.cashback = operation.check_summ * operation.cashback_percent
        operation.done = true
        operation.save

        user.bonus -= request_payload[:write_off]
        user.bonus += operation.cashback
        user.save
      end

      status 200
      json({
        status: 200,
        message: 'Данные успешно обновлены',
        operation: operation.to_h.except(*OPERATION_PARAMS_TO_SCRUB)
      })

    rescue StandardError => e
      status 400
      { error: e.message }.to_json
    end
  end

  

  post '/operation' do
    content_type :json
    begin
      request.body.rewind
      request_payload = JSON.parse(request.body.read, symbolize_names: true)

      user_id = request_payload[:user_id]
      positions =  request_payload[:positions]

      user = User[user_id]
      raise 'User missing' if user.nil?
    
      template = user.template
      positions.map! { |pos| position_mapper(pos, template) }

      total_discount = positions.reduce(0) {|sum, e| sum += e[:discount_summ]}.round.to_f
      total_cashback =  positions.filter {|e| e[:type] != 'noloyalty' }.reduce(0) {|sum, e| sum += e[:cashback]}.round.to_f

      total_sum = positions.reduce(0) {|sum, e| sum += e[:amount]}.round.to_f
      
      allowed_summ = positions.filter {|e| e[:type] != 'noloyalty' }.reduce(0) { |sum, e| sum += (e[:amount]) * (1 - e[:discount_percent]/100.0) }.round.to_f
      cashback_percent = total_sum == 0.0 ? 0.0 : total_cashback / total_sum
      discount_percent = total_sum == 0.0 ? 0.0 : total_discount / total_sum

      check_summ = total_sum - total_discount

      operation = Operation.new(
        user_id: user_id,
        cashback: total_cashback,
        cashback_percent: cashback_percent.round(4),
        discount: total_discount,
        discount_percent: discount_percent.round(4),
        check_summ: check_summ,
        done: false,
        allowed_write_off: check_summ > user.bonus ? user.bonus : check_summ 
      ).save

      status 200
      json({
        status: 200,
        user: user.to_h,
        operation_id: operation.id,
        summ: check_summ,
        positions: positions.map {|e| e.except(*POSITION_PARAMS_TO_SCRUB)},
        discount: {
          summ: total_discount,
          value: (discount_percent * 100.0).round(2).to_s + '%'
        },
        cashback: {
          existed_summ: user.bonus.to_i,
          allowed_summ: allowed_summ,
          value: (cashback_percent * 100.0).round(2).to_s + '%',
          will_add: total_cashback.to_i
        }
      })

    rescue StandardError => e
      status 400
      { error: e.message }.to_json
    end
  end

  private

  def type_desc(product = nil)
    case product&.type
    when 'noloyalty'
      "Не участвует в системе лояльности"
    when 'discount'
      "Дополнительная скидка #{product&.value}%"
    when 'increased_cashback'
      "Дополнительный кэшбек #{product&.value}%"
    else
      nil
    end
  end

  def position_mapper(position, template)
    product = Product[position[:id]]

    discount = template.discount
    cashback = template.cashback
    case product&.type
    when 'noloyalty'
      discount = 0
      cashback = 0
    when 'discount'
      discount += product.value.to_i
    when 'increased_cashback'
      cashback += product.value.to_i
    end

    
    price = position[:price]
    amount = price * position[:quantity]
    discount_summ = amount * (discount / 100.0)

    {
      id: position[:id],
      price: price,
      quantity: position[:quantity],
      type: product&.type,
      value: product&.value,
      type_desc: type_desc(product),
      discount_percent: discount.to_f,
      discount_summ: discount_summ,
    
      amount: amount,
      cashback: (amount - discount_summ) * (cashback / 100.0),
    }
  end

end