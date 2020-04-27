require 'active_support/all'
require 'parallel'
require_relative 'database'

class Object
  def metaclass
    class << self
      self
    end
  end
end

module PMap
  def pmap()
      out = []
      if block_given?
        out = Parallel.map(self,in_threads: 10) do |x|
          ActiveRecord::Base.connection.cache do
            ActiveRecord::Base.connection_pool.with_connection do
              yield(x)
            end
          end
        end
      else
          out = to_enum :mapp
      end
      out
  end
end

def time()
  time_begin = Time.now()
  yield
  time_end = Time.now()
  puts humanize(time_end-time_begin)
end

class Array
  include PMap
end

class ActiveRecord::Relation
  include PMap
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

    def self.timestamp_attributes_for_update
      super << "update_time"
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
      belongs_to :user_member_subscribe, primary_key: "member_id", foreign_key: "id"

      scope :valid, -> { where(valid_flag:"\x01") }
      scope :member, -> { where(vip_flag:"\x01") }

      scope :staff, -> { joins(:property).merge(UserProperty.staff) }
      scope :v0, -> { joins(:property).merge(UserProperty.v0) }
      scope :v1, -> { joins(:property).merge(UserProperty.v1) }
      scope :v2, -> { joins(:property).merge(UserProperty.v2) }
      scope :v3, -> { joins(:property).merge(UserProperty.v3) }
      scope :style, ->(value=nil) { joins(:property).merge(UserProperty.style(value)) }
      scope :marriage, ->(value=nil) { joins(:property).merge(UserProperty.marriage(value)) }
      scope :occupation_class, ->(value=nil) { joins(:property).merge(UserProperty.occupation_class(value)) }

      # 是否会员
      def member
        vip_flag=="\x01"
      end

      # 是否有效会员
      def valid
        valid_flag=="\x01"
      end

      # 完成订单购买转化率
      def purchase_rate
        return @purchase_rate if @purchase_rate

        @purchase_rate = orders.product.finish_purchase.purchase_rate
      end

      # add user property
      def to_json
        ret = super
        json = JSON.parse(ret)
        if property.photo.first then
          json[:photo] = @part.split(",") if @part = property.photo.first.value
        else
          json[:photo] = []
        end
        json[:photo].unshift(self.wx_avatar_url)
        json[:style] = @part.split(",") if @part = property.style.value.first
        json[:sel_style] = @part.split(",") if @part = property.sel_style.value.first
        json[:age] = ((Time.now - Time.zone.parse(property.birth.first.value))/3600/24/365).round
        json[:marriage] =  @part.split(",").first if @part = property.marriage.value.first.split(",")
        json[:occupation] = @part.split(",") if @part = property.occupation.value.first
        json[:heigth] =  @part.split(",").first if @part = property.heigth.value.first
        json[:weight] = @part.split(",").first if @part = property.weight.value.first
        json[:cup] = @part.split(",").first if @part = property.cup.value.first
        json[:up_size] = @part.split(",").first if @part = property.up_size.value.first
        json[:low_size] = @part.split(",").first if @part = property.low_size.value.first

        return json.to_json
      end

      def up_size
        property.up_size.value.first.split("/")
      end

      def lo_size
        property.low_size.value.first.split(",").map do |x| x.gsub(/\/.*/,"") end
      end

      def low_size
        size_map = {
            "24"=>"XS",
            "25"=>"S",
            "26"=>"S",
            "27"=>"M",
            "28"=>"L",
            "29"=>"XL",
            "30"=>"XXL",
            "31"=>"XXL",
        }

        property.low_size.value.first.split(",").map do |x|
            size_map[x.gsub(/\/.*/,"")]
        end.uniq

      end

      def check_size(spu)
        product_size_list = ProductSpu.where(spu:spu).warehouse.where(status:1).product_sku.map do |x| x.size end
        uplow = (ProductSpu.where(spu:spu).first.category[1][0] =="下"? "low" : "up")
        size = ""
        if (product_size_list.index("F"))
         size = "F"
        elsif (product_size_list.index("均码"))
         size = "均码"
        else
          if uplow=="up" then
            user_size = up_size
            product_size = product_size_list.map do |x| x[0] end
            match = product_size.product(user_size).to_a.filter do |x| x[0]==x[1] end
            size=match[0][0] if (match.size>0)
          else
            user_size = low_size
            product_size = product_size_list.map do |x| x[0] end
            match = product_size.product(user_size).to_a.filter do |x| x[0]==x[1] end
            size=match[0][0] if (match.size>0)
            # puts "user"+user_size.to_s
            # puts "product"+product_size.to_s
            # puts "match"+match.to_s
            # puts "size"+size.to_s
            if size==""
              user_size = lo_size
              product_size = product_size_list.map do |x| x[0] end
              match = product_size.product(user_size).to_a.filter do |x| x[0]==x[1] end
              size=match[0][0] if (match.size>0)
            end
          end
        end
        return size
      end
  end

  class UserProperty < WTRecord
    self.table_name = "t_user_member_property"

    belongs_to :user, primary_key: "id", foreign_key: "member_id"

    scope :marriage, ->(value=nil) {
      return filter = where(property_id:68) if value.nil?
      return filter = where(property_id:68).where(property_value:value) if not value.nil?
    }
    scope :staff, -> { where(property_id:83).where(UserProperty.arel_table[:property_value].matches("%亲友%")) }
    scope :v0, -> { where(property_id:83).where(UserProperty.arel_table[:property_value].matches("%V0%")) }
    scope :v1, -> { where(property_id:83).where(UserProperty.arel_table[:property_value].matches("%V1%")) }
    scope :v2, -> { where(property_id:83).where(UserProperty.arel_table[:property_value].matches("%V2%")) }
    scope :v3, -> { where(property_id:83).where(UserProperty.arel_table[:property_value].matches("%VIP用户%")) }
    scope :style, ->(value=nil) {
      style_list = ["非正式职业", "传统淑女", "胖妹", "猪猪女孩", "时髦潮酷类", "优衣库女孩类", "大女装", "暗黑酷女孩类", "小仙女时髦类", "设计师感时髦类", "温柔小姐姐类", "大学生", "日系森女", "澳牌姑娘", "比较时髦", "充返用户", "运动休闲类", "金融类职业", "高级名媛OL类", "学院风少女类", "复古类", "田园少女类", "朴实仙女类", "不时髦", "小红书KOL", "非常时髦", "孕妇/产后/宝妈", "女性印花类", "微博KOL"]
      value=nil if not style_list.index(value)
      return filter = where(property_id:83) if value.nil?
      return filter = where(property_id:83).where(UserProperty.arel_table[:property_value].matches("%#{value}%")) if not value.nil?
    }
    scope :up_size, -> { where(property_id:75) }
    scope :low_size, -> { where(property_id:76) }
    scope :photo, -> { where(property_id:77) }
    scope :birth, -> { where(property_id:52) }
    scope :sel_style, -> { where(property_id:30) }
    scope :occupation, -> { where(property_id:53) }
    scope :heigth, -> { where(property_id:36) }
    scope :weight, -> { where(property_id:69) }
    scope :cup, -> { where(property_id:70) }

    scope :occupation_class, ->(value) {
      # 个性化办公室
      # 企事业单位办公室
      # 商务办公室

      range=[]
      if value=="个性化办公室" then
        range = ['个体户/私营老板','主持人/艺人/模特','创业者','创意/文案人员','导演/制片人',
          '店长',"厨师","咖啡师/调酒师",
          '经纪人/顾问', '设计师',"摄影师","物流专员"]
        end
        if value=='企事业单位办公室' then
          range = ['主任','公务员','医护人员','医生','处级及以上干部','大学讲师/教授',
            '小学/中学教师',
            '工人','工程师','幼儿教师','校长','法官/检察官','科级干部','警察']
          end
          if value=='商务办公室' then
            range = [ "交易员/投资经理", "市场人员", "贸易专员/主管", "顾问", "服务人员",
               "销售/商务人员", "记者", "销售人员/顾问", "律师", "乘务员", "教练", "医药销售",
                "市场", "客服", "设计师/工程师", "生产管理层", "部门经理/主管",
                "精算师/量化分析师", "研发人员", "质检人员","销售人员/主管",'运营/市场/产品',
                '销售','销售人员',"硬件/制造/技术工程师","部门主管",'开发工程师','技术人员',
                '管理者/老版','工程师/技术人员','市场/产品','职员',"高级管理层","部门/项目经理",
                "采购专员/主管", "培训师","人事/财务/行政", "人事/财务/行政职员",]
          end
          if value=='其他' then
            range = ["其他", "家庭主妇",  "自由职业", "研究生在读", "大学在读",  "博士在读"]
          end

      where(id:where(property_id:53).map do |x| [x.id,x.value.split(",")] end.filter do |x| x[1].size==2 end.
        filter do |x| range.index(x[1][1]) end.map do |x| x[0] end)

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

      belongs_to :order_feedback, primary_key: "order_no", foreign_key: "order_no"
      belongs_to :order_feedback_detail, primary_key: "order_no", foreign_key: "order_no"

      scope :card, -> { where(type:1) }
      scope :product, -> { where(type:2) }
      scope :finish_purchase, -> { where("status >=35") }
      scope :onroad, -> {where(:status=>[25,30,35,40])}
      scope :inhouse, -> {where(:status=>[5,10])}

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
      scope :unsold, -> { where(status:[0,2]) }

      # 售出
      def sold
          status==1
      end

      def unsold
          status==0 or status==2
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

    scope :normal, -> { where(:status=>[0,1,2,3]) }
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

  class OrderFeedback < WTRecord
    self.table_name = "t_order_feedback"

    belongs_to :orders, primary_key: "order_no", foreign_key: "order_no"
  end

  class OrderFeedbackDetail < WTRecord
    self.table_name = "t_order_feedback_detail"

    belongs_to :orders, primary_key: "order_no", foreign_key: "order_no"
  end

  class UserMemberSubscribe < WTRecord
    self.table_name = "t_user_member_subscribe"

    belongs_to :user, primary_key: "id", foreign_key: "member_id"
  end
end
