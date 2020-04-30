require 'httparty'

module WTCube
  class BMS
    class << self
      def __init()
        @retry_token = "35b496f2a9794190993c3a93d6945783"
      end

      attr_accessor :retry_token

      def headers()
        headers = {
          "retry-token"  => @retry_token,
          'Content-Type' => 'application/json'
        }
      end

      def updateMatchingDivision(memberId,matchingDivision="10")
        url = "https://console.wetry.shop/console/user/member/updateMatchingDivision"
        json = { "memberId" => memberId, "matchingDivision" => matchingDivision }
        response = HTTParty.post(url, :headers => headers,:body => json.to_json)
        return JSON.parse(response.body)
      end


      def matchNextBox(order_no)
        url = "https://console.wetry.shop/console/order/order/matchNextBox/#{order_no}"
        response = HTTParty.post(url, :headers => headers)
        return JSON.parse(response.body)
      end

      def deleteOrderItem(order_no,spu)
        item_no = Order.where(order_no:order_no).item.where(spu:spu).id
        url = "https://console.wetry.shop/console/order/order/deleteOrderItem"
        json = {"itemIdList" => item_no, "deleteTags"=> "", "deleteRemark" => ""}
        response = HTTParty.post(url, :headers => headers,:body => json.to_json)
        return JSON.parse(response.body)
      end

      def addOrderItem(order_no,spu,size)
        url = "https://console.wetry.shop/console/order/order/addOrderItem"
        json = {"orderNo": order_no, "spu": spu, "size": size}
        response = HTTParty.post(url, :headers => headers,:body => json.to_json)
        return JSON.parse(response.body)
      end

      def matchComplete(order_no)
        url = "https://console.wetry.shop/console/order/order/matchComplete"
        json = {"ids": [Order.where(order_no:order_no).first.id], "type": 1}
        response = HTTParty.post(url, :headers => headers,:body => json.to_json)
        return JSON.parse(response.body)
      end

      def getMemberFilterJson(user_id)
        url = "https://console.wetry.shop/console/user/member/getMemberFilterJson"
        json = { "memberIds": user_id }
        response = HTTParty.post(url, :headers => headers,:body => json.to_json)
        return JSON.parse(response.body)
      end

      def updateSendTime(order_no,date,remark="提前")
        json = {"orderNo"=> order_no, "expectDay"=>  date.to_s(:db)[0,10], "remark" => remark}
        url = "https://console.wetry.shop/console/order/order/updateSendTime"
      end

      def api_call(url,json)
        response = HTTParty.post(url, :headers => headers,:body => json.to_json)
        return JSON.parse(response.body)
      end
    end
    self.__init()
  end
end
