class Operation

  def initialize(request)             # {"user_id"=>1,"positions"=> [{"id"=>1, "price"=>100, "quantity"=>3} ...]}
    @user_id = request["user_id"]
    @positions = request["positions"] # [{"id"=>1, "price"=>100, "quantity"=>3},{"id"=>2, "price"=>50, "quantity"=>2}...]
 
    
    @user = TEMPLATE.join(USER.where(id: @user_id), template_id: :id).to_a[0] # { :id=>1, :name=>"Иван", :discount=>0,:cashback=>5,
                                                                              #   :template_id=>1,:bonus=>0.8602e4 }                                                      
  end

  def product_without_discounts?(i)
    PRODUCT.where(id: i["id"]).empty?
  end

  def products_info
    @products = @positions.each_with_object({}) do |x,m| 
      i = product_without_discounts?(x) ? x : PRODUCT.where(id: x["id"]).to_a[0]
      m[x["id"]] = i.merge(x)
    end
    self             # { 1=>{"id"=>1, "price"=>100, "quantity"=>3},
                     #   2=>{:id=>2, :name=>"Молоко", :type=>"increased_cashback", :value=>"10", "id"=>2, "price"=>50, "quantity"=>2}...}
                     # }
  end

  def result
    user_discount = @user[:discount]/100
    user_cashback = @user[:cashback]/100
    total_price = 0
    total_cashback = 0
    total_discount = 0
    noloyality_sum = 0
    positions_info = []
   

    @positions.map do |position|
      position_clear_price = position["quantity"]*position["price"]
      total_price += position_clear_price
      noloyalty = false

      position_type = @products[position["id"]][:type]
      position_value = @products[position["id"]][:value].to_f
      position_discount = 0


      case position_type
      when "increased_cashback"
        total_cashback += position_clear_price*position_value/100
      when "discount"
        position_discount = position_clear_price*position_value/100
        total_discount += position_discount
      when "noloyalty"
        noloyality_sum += position_clear_price
        noloyalty = true
      end

      position_discount_value = noloyalty ? 0 : (position_discount + position_clear_price*user_discount)
      position_discount_precent = position_discount_value/position_clear_price
      positions_info <<  {
                            type: position_type,
                            value: position_value,
                            name: @products[position["id"]][:name],
                            discount_precent: position_discount_precent,
                            discount_value: position_discount_value,
                          }
    end

    total_cashback += total_price*user_cashback/100
    total_discount += total_price*user_discount/100

    check_sum = total_price - total_discount
    allowed_write_off = (check_sum - noloyality_sum) >= @user[:bonus] ? @user[:bonus] : (check_sum - noloyality_sum)
    
    bonus_info = {
                    balance: @user[:bonus],
                    allowed_write_off: allowed_write_off,
                    cashback_percent: (total_cashback/total_price*100).round(2),
                    calculated_cashback: total_cashback,
                  }              

    discount_info = {
                      total_discount: total_discount,
                      discount_percent: (total_discount/total_price*100).round(2),
                    }                   

    operation = OPERATION.insert(
                                   user_id: @user[:id],
                                   cashback: bonus_info[:calculated_cashback],
                                   cashback_percent: bonus_info[:cashback_percent],
                                   allowed_write_off: bonus_info[:allowed_write_off],
                                   discount: discount_info[:total_discount],
                                   discount_percent: discount_info[:discount_percent],
                                   check_summ: check_sum
                                )

    result = {
          user_info: @user[:name],
          operation_id: operation,
          check_sum: check_sum,
          bonus_info: bonus_info,
          discount_info: discount_info,
          positions: positions_info,
         }

  end
end
