require 'active_support/all'
require_relative 'database'

class Object
  def metaclass
    class << self
      self
    end
  end
end

module WTCube

  class WTRecord < Record
    scope :keep, -> { where(remove_flag:"\x00") }

    def keep
        remove_flag=="\x00"
    end

    def self.id
        self.pluck(primary_key)
    end

    class << self
      def belongs_to(name, scope = nil, **options)
        super

        self.metaclass.send(:define_method, :"#{name}") do
            primary_key = (options[:primary_key] or "id")
            foreign_key = (options[:foreign_key] or "id")
            classname = (options[:class_name] or name)
            class_name = classname.to_s.singularize.camelize.constantize
            class_name.where({primary_key.to_sym=>all.select(foreign_key).map {|x| x.send(foreign_key) } })
        end
      end

      def has_many(name, scope = nil, **options, &extension)
        super

        if options[:through] then
          self.metaclass.send(:define_method, :"#{name}") do
              self.send(options[:through]).send(name)
          end
        else
          self.metaclass.send(:define_method, :"#{name}") do
              primary_key = (options[:primary_key] or "id")
              foreign_key = (options[:foreign_key] or "id")
              classname = (options[:class_name] or name)
              class_name = classname.to_s.singularize.camelize.constantize
              # class_name.where({foreign_key.to_sym=>all.select(primary_key).map {|x| x.send(primary_key) } })
              class_name.where({foreign_key.to_sym=>self.pluck(primary_key) })
          end
        end
      end

    end
  end

  # ----------- Data Model -------------

  class User < WTRecord
      self.table_name = "t_user_member"

      has_many :property, class_name:"UserProperty", primary_key: "id", foreign_key: "member_id"
      has_many :orders, foreign_key: "member_id"

      scope :valid, -> { where(valid_flag:"\x01") }

      # 是否有效会员
      def valid
        valid_flag=="\x01"
      end

      # 完成订单购买转化率
      def purchase_rate
        return @purchase_rate if @purchase_rate

        @purchase_rate = orders.product.finish_purchase.purchase_rate
      end
  end

  class UserProperty < WTRecord
    self.table_name = "t_user_member_property"

    belongs_to :user, primary_key: "id", foreign_key: "member_id"

    scope :marriage, ->(value=nil) {
      return filter = where(property_id:68) if value.nil?
      return filter = where(property_id:68).where(property_value:value) if not value.nil?
    }
    ## 值
    def self.value
      self.pluck(:property_value)
    end

    def value
      property_value
    end
  end


  class Orders < WTRecord
      self.table_name = "t_order_orders"

      belongs_to :user, foreign_key: "member_id"
      has_many :item, primary_key: "order_no", foreign_key: "order_no"
      has_many :product_spu, through: :item

      scope :card, -> { where(type:1) }
      scope :product, -> { where(type:2) }
      scope :finish_purchase, -> { where("status >=35") }
      scope :onroad, -> {where(:status=>[25,30,35,40])}

      # 购卡
      def card
          type==1
      end

      # 购衣
      def product
          type==2
      end

      # 完成购买决策
      def finish_purchase
        status >= 35
      end

      def onroad
        [25,30,35,40].index(status) != nil
      end

      # 订单购买转化率
      def purchase_rate
         return item.sold.size / item.keep.size
      end

      def self.purchase_rate
        item = self.item
        keep = item.keep
        sold = keep.sold

        keep_size = keep.size
        sold_size = sold.size
        return sold_size.to_f/keep_size
      end
  end
  class Order < Orders
    self.table_name = "t_order_orders"
  end


  class Item < WTRecord
      self.table_name = "t_order_order_items"

      belongs_to :orders, primary_key: "order_no", foreign_key: "order_no"
      belongs_to :product_spu, primary_key: "spu", foreign_key: "spu"
      belongs_to :product_sku, primary_key: "sku", foreign_key: "sku"
      belongs_to :warehouse, primary_key: "id", foreign_key: "product_id"

      scope :sold, -> { where(status:1) }

      # 售出
      def sold
          status==1
      end
  end

  class ProductSpu < WTRecord
    self.table_name = "t_product_spu"

    has_many :item, primary_key: "spu", foreign_key: "spu"
    has_many :property, class_name:"ProductSpuProperty", primary_key: "spu", foreign_key: "spu"
    has_many :picture, class_name:"ProductPicture", primary_key: "spu", foreign_key: "spu"
    has_many :orders, through: :item
    has_many :product_sku, primary_key: "spu", foreign_key: "spu"
    has_many :warehouse, through: :product_sku

    def sold_count
      item.sold.count
    end

    def category
      dict =[
  [4,0,"上装"],
  [6,0,"下装裙"],
  [5,0,"下装裤"],
  [11,0,"专业运动装"],
  [14,0,"其他"],
  [13,0,"内衣"],
  [8,0,"外套"],
  [9,0,"大衣"],
  [10,0,"套装"],
  [12,0,"泳装"],
  [7,0,"连衣裙"],
  [1,0,"配饰"],
  [3,0,"鞋子"],
  [2,0,"首饰"],
  [19,1,"丝巾"],
  [20,1,"包包"],
  [18,1,"围巾"],
  [15,1,"墨镜"],
  [17,1,"帽子"],
  [16,1,"腰带"],
  [26,2,"发饰"],
  [25,2,"戒指"],
  [24,2,"手镯手链"],
  [111,2,"挂坠"],
  [22,2,"耳夹"],
  [21,2,"耳环"],
  [27,2,"胸针"],
  [23,2,"项链"],
  [30,3,"凉鞋"],
  [29,3,"拖鞋"],
  [34,3,"短靴"],
  [33,3,"穆勒鞋"],
  [32,3,"粗跟高跟鞋"],
  [31,3,"细跟高跟鞋"],
  [28,3,"运动鞋"],
  [35,3,"长靴"],
  [38,4,"T恤"],
  [40,4,"上衣"],
  [41,4,"卫衣"],
  [36,4,"吊带背心"],
  [37,4,"打底衫"],
  [43,4,"毛衣"],
  [42,4,"羊绒衫"],
  [39,4,"衬衫衬衣"],
  [44,4,"针织衫"],
  [53,5,"哈伦裤"],
  [54,5,"喇叭裤"],
  [45,5,"打底裤"],
  [46,5,"牛仔短裤"],
  [47,5,"牛仔长裤"],
  [51,5,"直筒裤"],
  [48,5,"短裤"],
  [55,5,"裙裤"],
  [49,5,"运动裤"],
  [50,5,"铅笔裤"],
  [52,5,"阔腿裤"],
  [57,6,"A字裙"],
  [61,6,"不对称以及垂褶裙"],
  [62,6,"伞裙"],
  [58,6,"包臀裙"],
  [63,6,"牛仔裙"],
  [60,6,"百褶裙"],
  [59,6,"直筒裙"],
  [56,6,"迷你裙"],
  [65,7,"梭织连衣裙"],
  [66,7,"轻礼服裙"],
  [67,7,"连体裤"],
  [64,7,"针织连衣裙"],
  [69,8,"坎肩"],
  [71,8,"外套"],
  [76,8,"斗篷"],
  [74,8,"派克夹克"],
  [75,8,"牛仔外套"],
  [73,8,"皮夹克"],
  [70,8,"薄开衫"],
  [72,8,"西装外套"],
  [68,8,"马甲"],
  [77,9,"棉服"],
  [82,9,"毛皮大衣"],
  [80,9,"短款大衣"],
  [78,9,"羽绒服"],
  [81,9,"长款大衣"],
  [79,9,"风衣"],
  [84,10,"上衣裙装套装"],
  [85,10,"上衣裤装套装"],
  [83,10,"西装套装"],
  [87,11,"上衣"],
  [89,11,"其他"],
  [86,11,"背心"],
  [88,11,"裤装"],
  [90,12,"比基尼"],
  [93,12,"泳装套装"],
  [94,12,"泳装罩衫"],
  [91,12,"连体衣"],
  [92,12,"防晒衣"],
  [96,13,"丝袜"],
  [100,13,"内衣套装"],
  [99,13,"内裤"],
  [103,13,"分体睡衣"],
  [95,13,"短袜"],
  [98,13,"胸罩"],
  [101,13,"贴身衣"],
  [102,13,"贴身裤"],
  [104,13,"连衣睡衣"],
  [109,13,"针织袜"],
  [106,14,"护理液"],
  [114,14,"护肤品"],
  [107,14,"防晒伞"],
  [113,14,"面膜"],
  [105,14,"香氛"]]
      match = dict.filter do |x| x[0]==self.category_id end.first
      if match[1] == 0 then
        return [match[2],match[2]]
      else
        match_parent = dict.filter do |x| x[0]==match[1] end.first
        return [match[2],match_parent[2]]
      end
    end
  end


  class ProductSku < WTRecord
    self.table_name = "t_product_sku"

    belongs_to :product_spu, primary_key: "spu", foreign_key: "spu"
    has_many :item, primary_key: "sku", foreign_key: "sku"
    has_many :warehouse, primary_key: "id", foreign_key: "sku_id"
  end

  class ProductSpuProperty < WTRecord
    self.table_name = "t_product_spu_property"

    belongs_to :product_spu, primary_key: "spu", foreign_key: "spu"
    scope :featured, -> { where(property_id:74) }

    ## 值
    def self.value
      self.pluck(:property_value)
    end
  end

  class ProductPicture < WTRecord
    self.table_name = "t_product_picture"

    belongs_to :product_spu, primary_key: "spu", foreign_key: "spu"

    scope :first_pic, -> { where(first_pic_flag:"\x01") }

    def self.url
      if first then
        first.url
      else
        ""
      end
    end

    # 首图
    def first_pic
        first_pic_flag=="\x01"
    end
  end

  class Warehouse < WTRecord
    self.table_name = "t_warehouse_products"

    belongs_to :product_sku, primary_key: "id", foreign_key: "sku_id"
    has_many :product_spu, through: :product_sku
    has_many :item, foreign_key: "product_id"

    scope :sold, -> { where(status:3) }
    scope :unsold, -> { where(:status=>[0,1,2]) }
    scope :inorder, -> { where(:status=>[0,1]) }

    # 售出
    def sold
        status==3
    end

    def unsold
        [0,1,2].index(status) != nil
    end

    def inorder
        [0,1].index(status) != nil
    end

  end
end
