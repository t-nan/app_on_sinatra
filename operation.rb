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
    user_discount = @user[:discount].to_f/100
    user_cashback = @user[:cashback].to_f/100
    total_price = 0
    total_cashback = 0
    total_discount = 0
    noloyalty_sum = 0
    positions_info = []
    product_discount = 0
  
    @positions.map do |position|
      position_clear_price = position["quantity"]*position["price"]
      total_price += position_clear_price

      position_type = @products[position["id"]][:type]
      position_value = @products[position["id"]][:value].to_f/100
      type = {"increased_cashback" => "Дополнительный кэшбэк", "discount" => "Дополнительная скидка", "noloyalty" => "Не участвует в системе лояльности"}
      type_desc = @products[position["id"]].has_key?(:type) ? "#{type[position_type]} #{@products[position["id"]][:value].to_i} %" : nil
   
      if position_type == "noloyalty"
        discount_by_product = 0
        discount_by_template = 0 
        noloyalty_sum += position_clear_price
      elsif position_type == "discount"
        discount_by_product = position_clear_price * position_value
        discount_by_template = (position_clear_price - discount_by_product) * user_discount     
      elsif position_type == "increased_cashback" || position_type == nil
        discount_by_product = 0
        discount_by_template = position_clear_price  * user_discount  
      end

      discount_all = discount_by_template + discount_by_product
      discount_percent = discount_all/position_clear_price *100
      total_discount += discount_all
      product_discount += discount_by_product

      if position_type == "noloyalty"
        cashback_by_product = 0
        cashback_by_template = 0
      elsif position_type == "discount" 
        cashback_by_product = 0
        cashback_by_template = (position_clear_price - discount_all) * user_cashback
      elsif position_type == "increased_cashback"
        cashback_by_product = (position_clear_price - discount_by_template) * position_value
        cashback_by_template = (position_clear_price - discount_by_template) * user_cashback
      elsif position_type == nil
        cashback_by_product = 0
        cashback_by_template = (position_clear_price - discount_by_template) * user_cashback
      end

      cashback_all = cashback_by_template + cashback_by_product
      total_cashback += cashback_all

      positions_info << {
                          id: position["id"],
                          price: position["price"],
                          quantity: position["quantity"],
                          type: position_type,
                          value: position_value *100,
                          type_desc: type_desc ,
                          discount_percent: discount_percent,
                          discount_summ: discount_all
                        }
    end

      check_sum = total_price - total_discount
      allowed_sum = total_price - product_discount - noloyalty_sum
      allowed_write_off = (check_sum - noloyalty_sum) >= @user[:bonus] ? @user[:bonus] : (check_sum - noloyalty_sum)

      user_info = { id: @user[:id],
                    template_id: @user[:template_id],
                    name: @user[:name],
                    balance: @user[:bonus].to_f 
                  }  

      discount_info = {
                        sum: total_discount,
                        value: (total_discount/total_price*100).round(2)
                      }

      cashback_info = { 
                        existed_summ: @user[:bonus].to_f,
                        allowed_summ: allowed_sum,
                        value: (total_cashback/total_price * 100).round(2),
                        will_add: total_cashback.round
                      }

      operation = OPERATION.insert(
                                   user_id: @user[:id],
                                   cashback: total_cashback,
                                   cashback_percent: cashback_info[:value],
                                   allowed_write_off: allowed_write_off,
                                   discount: total_discount,
                                   discount_percent: discount_info[:value],
                                   check_summ: check_sum
                                  )

    result = {  
                status: 200,
                user: user_info,
                operation_id: operation,
                summ: check_sum,
                positions: positions_info,
                discount: discount_info,
                cashback: cashback_info
             }
                                      
       
  end
end
