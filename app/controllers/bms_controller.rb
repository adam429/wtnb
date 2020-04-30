require_relative "../../wt-iruby/wtnb/wtnb.rb"
require_relative "../../wt-iruby/wtnb/wtbms.rb"

connect_db("online")
disable_cache()

class BmsController < ApplicationController
  def deleteOrderItem
    render :plain=> WTCube::BMS.deleteOrderItem(params[:order_no],params[:spu]).to_s
  end

  def addOrderItem
    render :plain=> WTCube::BMS.addOrderItem(params[:order_no],params[:spu],params[:size]).to_s
  end
end
