require 'bundler'
Bundler.require

require 'sinatra/json'
require "sinatra/namespace"

Sequel.connect('sqlite://test.db')
Dir["#{File.dirname(__FILE__)}/models/**/*.rb"].each {|file| require file }

class App < Sinatra::Base
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

  def mapper(pos)
    product = Product[pos[:id]]

    _discount = template.discount
    _cashback = template.cashback
    case product&.type
    when 'noloyalty'
      _discount = 0
      _cashback = 0
    when 'discount'
      _discount += product.value.to_i
    when 'increased_cashback'
      _cashback += product.value.to_i
    end

    
    price = pos[:price]
    amount = price * pos[:quantity]

    {
      id: pos[:id],
      price: price,
      quantity: pos[:quantity],
      amount: amount,

      type: product&.type,
      value: product&.value,
      type_desc: type_desc(product),
      discount_percent: _discount.to_f,
      discount_summ: amount * (_discount / 100.0),

      cashback: (amount - amount * (_discount / 100.0))*(_cashback/100.0),
    }
  end


  
  post '/submit' do

  end


  post '/operation' do
    content_type :json
    begin
      request.body.rewind
      @request_payload = JSON.parse(request.body.read, symbolize_names: true)

      user_id = @request_payload[:user_id]
      user = User[user_id]
      raise 'User missing' if user.nil?
    
  
      template = user.template
      positions =  @request_payload[:positions]


      s = positions.map do |pos|
        mapper(pos, template)
      end
=begin
        product = Product[pos[:id]]

        _discount = template.discount
        _cashback = template.cashback
        case product&.type
        when 'noloyalty'
          _discount = 0
          _cashback = 0
        when 'discount'
          _discount += product.value.to_i
        when 'increased_cashback'
          _cashback += product.value.to_i
        end

        
        price = pos[:price]
        amount = price * pos[:quantity]

        {
          id: pos[:id],
          price: price,
          quantity: pos[:quantity],
          amount: amount,

          type: product&.type,
          value: product&.value,
          type_desc: type_desc(product),
          discount_percent: _discount.to_f,
          discount_summ: amount * (_discount / 100.0),

          cashback: (amount - amount * (_discount / 100.0))*(_cashback/100.0),
        }

      end
=end

      total_discount = s.reduce(0) {|sum, e| sum += e[:discount_summ]}
      total_sum = s.reduce(0) {|sum, e| sum += e[:amount]}

      total_cashback =  s.reduce(0) {|sum, e| sum += e[:cashback]}

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
=end
      puts "cashback - #{user.template[:cashback]}% - #{user.template[:cashback]/100.0}" 

      PARAMS_TO_SCRUB = [ :price2, :_amount, :cashback, :total_cashback, :amount ]

      status 200
      json({
        status: 200,
        user: user.values.map {|k, e| e.is_a?(BigDecimal) ? [k, e.to_f.to_s] : [k, e]}.to_h,
        operation_id: 23,
        #cashback: total_cashback,
        #cashback_percent: "#{(total_cashback.to_f/total_sum.to_f * 100.0).round(2)} %",
        #discount: 0,
        #discount_percent: 0,
        #template: user.template.values,
        summ: total_sum - total_discount,
        positions: s.map {|e| e.except(*PARAMS_TO_SCRUB)},
        #total_sum: total_sum,
        #total_discount: total_discount,
        discount: {
          summ: total_discount,
          value: ((1-(total_sum - total_discount)/total_sum)*100).round(2).to_s + '%'
        },
        cashback: {
          existed_summ: user.bonus.to_i,
          allowed_summ: (total_cashback/user.bonus).to_s('F'),
          value: (total_cashback.to_i/total_sum.to_f*100).round(2).to_s + '%',
          will_add: total_cashback.to_i
        }
      })

    rescue StandardError => e
      status 400
      { error: e.message }.to_json
    end
  end
end