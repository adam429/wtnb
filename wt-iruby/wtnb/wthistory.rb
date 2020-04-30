require_relative 'wtmodel'

module WTCube
  # ----------- Load Histroy --------------
  class History
    class << self
      attr_accessor :history

      def history_config()
        [[UserProperty,"t_user_member_property"],
        [User,"t_user_member"],
        [Order,"t_order_orders"],
        [Item,"t_order_order_items"],
        [ProductSpu,"t_product_spu"],
        [ProductSku,"t_product_sku"],
        [ProductSpuProperty,"t_product_spu_property"],
        [ProductPicture,"t_product_picture"],
        [Warehouse, "t_warehouse_products"]]
      end

      def set(date)
        if @history != date then
          @history = date
          _load_history(@history)
          ActiveRecord::Base.connection.query_cache.clear
        end
      end

      def _load_history(date=nil)
        if date.nil?
          history_config.each do |x|
            x[0].table_name = x[1]
          end
        else
          if date == Time.zone.parse(date).to_s(:db)[0,10].gsub(/-/,'')
            history_config.each do |x|
              table = x[1]
              htable = table.gsub(/^t_/,"h_")
              view = table.gsub(/^t_/,"v_")
              sql = "CREATE OR REPLACE VIEW #{view} AS SELECT * FROM #{htable} WHERE valid_from <= STR_TO_DATE('#{date}','%Y%m%d') and STR_TO_DATE('#{date}','%Y%m%d') <=valid_to"
              exec_sql(sql)
              x[0].table_name = view
            end
          else
            return false
          end
        end
      end
    end
  end
end
