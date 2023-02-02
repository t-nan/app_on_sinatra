class Submit

  def initialize(request) # {"user"=>{"id"=>1, "template_id"=>1, "name"=>"Иван", "bonus"=>"10000.0"}, "operation_id"=>18, "write_off"=>150}
    @operation_id = request["operation_id"]
    @user_id = request["user"]["id"]
    @name = request["user"]["name"]
    @bonus = request["user"]["bonus"]
    @write_off = request["write_off"]

    @user = USER.where(id: @user_id).to_a[0]
    @operation = OPERATION.where(id: @operation_id , user_id: @user_id).to_a[0]
  end

  def update_entries
    bonus_in_db = @user[:bonus]
    @available_for_write_off = @write_off if @write_off <= bonus_in_db
    actual_bonus = bonus_in_db - @available_for_write_off

    DB.transaction do
      operation = OPERATION.where(id: @operation_id , user_id: @user_id)
      entry = operation.update(done: 1, write_off: @available_for_write_off)
      bonus = USER.where(id: @user_id).update(bonus: actual_bonus)
    end
    self
  end

  def result
    operation = { 
                  user_id: @operation[:user_id],
                  cashback: @operation[:cashback],
                  cashback_percent: @operation[:cashback_percent],
                  discount: @operation[:discount],
                  discount_percent: @operation[:discount_percent],
                  write_off: @operation[:write_off],
                  payment: @operation[:check_summ] - @available_for_write_off
                } 
  end

end
 