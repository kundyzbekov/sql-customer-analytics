-- create database final_project;
-- select * from customers;

-- update customers 
-- set gender = NULL 
-- where gender = '';

-- update customers 
-- set age = NULL 
-- where age = '';

-- alter table customers 
-- modify age int null;

-- create table transactions(
-- date_new date,
-- Id_check int,
-- ID_client int,
-- Count_products decimal(10,3),
-- Sum_payment decimal(10,2)
-- )

-- load data infile "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\transactions_final.csv"
-- into table transactions
-- fields terminated by ','
-- lines terminated by '\n'
-- ignore 1 rows;

select * from transactions;
select * from customers;
#-------------------------------------------------------------------
#1
with filtered_transactions as (
    SELECT 
        t.ID_client,
        t.Id_check,
        DATE_FORMAT(t.date_new, '%Y-%m') as year_mon,
        t.Sum_payment
    from transactions t
    where t.date_new >= '2015-06-01'
      and t.date_new < '2016-06-01'
),
monthly_activity as (
	select id_client
    , count(distinct year_mon) as active_month
    from filtered_transactions
    group by id_client
),
active_clients as (
	select id_client
    from monthly_activity
    where active_month = 12
), 
transactions_stats as (
	select ft.id_client
		, count(ft.id_check) as operation_count
		, sum(ft.sum_payment)/count(ft.id_check) as avg_check
		, sum(ft.sum_payment)/12 as avg_monthly
	from filtered_transactions ft
    join active_clients ac
    on ft.id_client = ac.id_client
    group by ft.id_client
)

select c.*
	, ts.avg_check
    , ts.avg_monthly
    , ts.operation_count
from customers c 
join transactions_stats ts
on c.Id_client = ts.id_client;

#2
with filtered_transactions as (
    SELECT 
        t.ID_client,
        t.Id_check,
        c.gender,
        DATE_FORMAT(t.date_new, '%Y-%m') as year_mon,
        t.Sum_payment
    from transactions t
    join customers c 
    on t.ID_client = c.Id_client
    where t.date_new >= '2015-06-01'
      and t.date_new < '2016-06-01'
),
monthly_avg as (
	select year_mon
        , count(id_check) as operations_monthly
        , count(distinct id_client) as unique_clients
        , sum(sum_payment) as total_payment_monthly
		, avg(sum_payment) as avg_monthly
	from filtered_transactions
    group by year_mon
),
global_totals AS (
    select 
        count(id_check) as total_operations_year,
        sum(sum_payment) as total_sum_year
    from filtered_transactions
),
gender_stats as (
	select year_mon
		, gender
        , count(distinct id_client) as gender_clients
        , sum(sum_payment) as gender_sum
	from filtered_transactions
    group by year_mon, gender
),
gender_totals AS (
    SELECT 
        year_mon,
        SUM(gender_clients) AS total_clients_month,
        SUM(gender_sum) AS total_gender_payment_month
    FROM gender_stats
    GROUP BY year_mon
),
gender_percentages AS (
    select 
        g.year_mon,
        g.Gender,
        g.gender_clients,
        g.gender_sum,
        round(g.gender_clients / t.total_clients_month * 100, 2) as gender_share_clients,
        round(g.gender_sum / t.total_gender_payment_month * 100, 2) as gender_share_payment
    from gender_stats g
    join gender_totals t on g.year_mon = t.year_mon
),
monthly_summary as(
	select m.year_mon
	, round(avg_monthly,2) as avg_check_monthly
    , m.operations_monthly as avg_operations_monthly
    , m.unique_clients as avg_unique_clients
    , round(m.total_payment_monthly/gt.total_sum_year * 100, 2) as monthly_payment_share
    , round(m.operations_monthly/gt.total_operations_year * 100, 2) as monthly_operations_share
from monthly_avg m, global_totals gt
)

select ms.*
	, gp.gender
    , gp.gender_clients
    , gp.gender_sum
	, gp.gender_share_clients
    , gp.gender_share_payment
from monthly_summary ms
join gender_percentages gp 
on ms.year_mon = gp.year_mon
order by ms.year_mon, gp.gender;

#3
with transactions_extended as (
    select 
        t.Id_check
        , t.ID_client
        , t.Sum_payment
        , date_format(t.date_new, '%Y-%m-%d') as date_full
        , quarter(t.date_new) as q_num
        , year(t.date_new) as y_num
		, concat(year(t.date_new), 'Q', quarter(t.date_new)) as quarterr
        , c.Age
        , case
            when c.Age is null then 'Unknown'
            when c.Age < 10 then '0-9'
            when c.Age >= 90 then '90+'
            else concat(floor(c.Age / 10) * 10, '-', floor(c.Age / 10) * 10 + 9)
        end as age_group
    from transactions t
    join customers c 
    on t.ID_client = c.Id_client
),
quarterly_base as (
    select 
        age_group
        , quarterr
        , count(Id_check) as avg_operations
        , sum(Sum_payment) as avg_sum
    from transactions_extended
    group by age_group, quarterr
),
quarter_totals as (
    select 
        quarterr
        , sum(avg_operations) as total_ops_q
        , sum(avg_sum) as total_sum_q
    from quarterly_base
    group by quarterr
)
select 
    qb.age_group
    , qb.quarterr
    , qb.avg_operations
    , qb.avg_sum
    , qt.total_ops_q
    , qt.total_sum_q
    , round(qb.avg_operations / qt.total_ops_q * 100, 2) as operation_pct
    , round(qb.avg_sum / qt.total_sum_q * 100, 2) as payment_pct
from quarterly_base qb
join quarter_totals qt on qb.quarterr = qt.quarterr
order by qb.quarterr, qb.age_group;








