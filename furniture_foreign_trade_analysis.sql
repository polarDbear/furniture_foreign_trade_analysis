use furniture_analysis;

desc furniture_orders;

-- 去除多余列
alter table furniture_orders
drop column Column1;

-- 修改日期列数据类型
alter table furniture_orders
modify order_time DATE,
modify planed_ship_date DATE,
modify actual_ship_date DATE;


-- 1、总览表
create table orders_overview as
with order_info_table as (
select 
*,
-- 发货延误情况
case when DATEDIFF(actual_ship_date, planed_ship_date) > 0 then 1 else 0 end as delay_status,
-- 延误天数
DATEDIFF(actual_ship_date, planed_ship_date) as delay_days
from furniture_orders
),
overview as (
select oit.*,
p.receivable,
p.received,
p.unpaid,
p.pay_date
from order_info_table oit
join payment_information p
on oit.order_id = p.order_id
)
select * from overview;


-- 2、销售量与物料储备分析
create table orders_material_table as 
with bom_info_table as (
select case 
	when product_code = 'P001' then '沙发'
	when product_code = 'P002' then '餐桌'
	when product_code = 'P003' then '柜类'
end as furniture_category,
material_code,
consume_qty
from bom_info
),
sales_needed_material as (
select 
bt.material_code,
sum(fn_o.qty * bt.consume_qty) as needed_material
from furniture_orders fn_o
join bom_info_table bt
on bt.furniture_category = fn_o.category and fn_o.order_status in ('生产中', '待排产')
group by bt.material_code
),
needed_stock_table as (
select 
snm.material_code,
s.material_name,
s.material_type, 
snm.needed_material,
s.current_stock,
s.safe_stock,
(snm.needed_material - s.current_stock) as shortage_qty,
case 
	when s.current_stock >= snm.needed_material then '库存充足' else '缺料预警' 
end as shortage_warning
from sales_needed_material snm
left join stock_info s
on snm.material_code = s.material_code
order by shortage_qty desc
)
select * from needed_stock_table limit 10;

#结论：为完成本批订单，现有物料储备中的 【海绵】 数量不足，需要补充；另外，布艺面料的储备量虽然能够满足生产任务，但计算后的余量偏低，考虑是否需要增加一些储备，以防生产过程中不可预期的额外损耗。