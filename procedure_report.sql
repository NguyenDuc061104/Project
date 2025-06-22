    -- Creater Information 
    -- ---------------------
   	-- Procedure name: backdate_month_prc 
    -- Author: Nguyễn An Đức
    -- Created : March 2025

    -- ---------------------


    -- ---------------------
    -- SUMMARY Processing Stream
    -- ---------------------
    -- step 1: Declare Variables
    -- step 2: Execute SQL Statements And Process Logic
    -- step 3: Calculate Values For tmp_head
    -- step 4: Calculate Values For tmp_area
    -- step 5: Target fact_profit_loss_area_by_monthly, fact_ranking_asm
CREATE OR REPLACE PROCEDURE backdate_month_prc(monthdate int default null)
LANGUAGE plpgsql
AS $$
declare 
-- 	step 1: declare variables
	sum_du_no_sau_wo NUMERIC := 0;
    sum_du_no_trc_wo NUMERIC := 0;
    sum_du_no_xau_trc_wo NUMERIC := 0;
    sum_du_no_xau_sau_wo NUMERIC := 0;
    writeoff_balance NUMERIC := 0;
    writeoff_balance_xau NUMERIC := 0;
    monthdate_key INT;
   	area_name_arr varchar[]:=  array['Đông Bắc Bộ','Tây Bắc Bộ','Đồng Bằng Sông Hồng','Bắc Trung Bộ','Nam Trung Bộ','Tây Nam Bộ','Đông Nam Bộ'];
   	area_arr varchar[]:= array['dong_bac_bo','tay_bac_bo','db_song_hong','bac_trung_bo','nam_trung_bo','tay_nam_bo','dong_nam_bo'];
    area_cde_arr varchar[] := array['B','C','D','E','F','G','H'];
   	sort_id_max int :=32;
    query text;
   	i int ;
    j int ;
   	m int;
   	n int;
BEGIN
	-- step 2: Execute SQL Statements And Process Logic
--	if monthdate is null then 
--		month_key_in := TO_CHAR(CURRENT_DATE - INTERVAL '1 month','YYYYMM')::int;
--	else month_key_in = monthdate
    monthdate_key := 202300 + monthdate;
    truncate table tmp_table;
   	truncate table tmp_report;
   	truncate table tmp_area;
   	truncate table fact_ranking_asm ;
   	truncate table fact_profit_loss_area_by_monthly;
   	truncate table tmp_head;
   	truncate table du_no_sau_wo ;
 	FOR n IN 1..array_length(area_cde_arr, 1) -- run loop in order to insert specific area
    LOOP
        sum_du_no_trc_wo := 0;
        sum_du_no_xau_trc_wo := 0;
        FOR m IN 1..monthdate
        loop 
            SELECT 
                COALESCE(SUM(outstanding_principal), 0) 
            INTO sum_du_no_sau_wo
            FROM 
                fact_kpi_month_data a
            JOIN 
                dim_city b ON a.pos_city = b.province 
            WHERE 
                kpi_month = 202300 + m
                AND province_code = area_cde_arr[n];
			SELECT 
    			COALESCE(SUM(CAST(write_off_balance_principal AS NUMERIC)), 0)
			INTO writeoff_balance
			FROM 
			fact_kpi_month_data a
			JOIN 
    			dim_city b ON a.pos_city = b.province  
			WHERE  write_off_month between 202300 + 1 AND 202300 + m 
			and province_code = area_cde_arr[n];
            sum_du_no_trc_wo := sum_du_no_trc_wo + sum_du_no_sau_wo + writeoff_balance;
           --accumulate du_no_xau for each month
            SELECT 
                COALESCE(SUM(outstanding_principal), 0) 
            INTO sum_du_no_xau_sau_wo
            FROM 
                fact_kpi_month_data a
            JOIN 
                  dim_city b ON a.pos_city = b.province
            WHERE 
                kpi_month = 202300 + m
                AND max_bucket > 2 
                and province_code = area_cde_arr[n]; 
            SELECT 
                COALESCE(SUM(write_off_balance_principal), 0)
            INTO writeoff_balance_xau
            FROM 
                fact_kpi_month_data a
            JOIN 
                dim_city b ON a.pos_city = b.province 
            WHERE 
                write_off_month between 202300 + 1 and 202300 + m
                AND province_code = area_cde_arr[n]
                AND max_bucket > 2;
            sum_du_no_xau_trc_wo := sum_du_no_xau_trc_wo + sum_du_no_xau_sau_wo + writeoff_balance_xau;
        END LOOP;
        sum_du_no_trc_wo := sum_du_no_trc_wo / monthdate;
        sum_du_no_xau_trc_wo := sum_du_no_xau_trc_wo / monthdate;
       	INSERT INTO tmp_table (rate, area_code,du_no)
      	VALUES (sum_du_no_xau_trc_wo / sum_du_no_trc_wo, area_cde_arr[n], sum_du_no_trc_wo);
    END LOOP;
   
   
   
-- step 3: Calculate Values For tmp_head
insert into tmp_head(id,amount)
--Lãi trong hạn
SELECT 
    14 AS id,
    ROUND(SUM(amount), 2) as amount
FROM
    fact_txn_month_raw_data ftmrd 
WHERE 
    account_code IN ('702000030002', '702000030001', '702000030102') 
    and extract(month from transaction_date) <= monthdate  and substring(analysis_code,9,1) ='0'
UNION ALL
--Lãi quá hạn
SELECT 
    15 AS id,
    ROUND(SUM(amount), 2) as amount
FROM 
    fact_txn_month_raw_data ftmrd 
WHERE
    account_code IN ('702000030012', '702000030112') 
    and extract(month from transaction_date) <= monthdate  and substring(analysis_code,9,1) ='0'
UNION ALL
--Phí bảo hiểm
SELECT 
    16 AS id,
    ROUND(SUM(amount), 2) as amount
FROM 
    fact_txn_month_raw_data ftmrd 
WHERE 
    account_code IN ('716000000001') 
    and extract(month from transaction_date) <= monthdate  and substring(analysis_code,9,1) ='0'
union all
--Phí tăng hạn mức
select 
17 as id,
round(sum(amount),2) as amount
from fact_txn_month_raw_data ftmrd 
where 
account_code in ('719000030002')
and extract(month from transaction_date) <= monthdate  and substring(analysis_code,9,1) ='0'

union all 
--Phí thanh toán chậm, thu từ ngoại bảng
select 
18 as id,
round(sum(amount),2) as amount
from fact_txn_month_raw_data ftmrd 
where account_code in ('719000030003','719000030103','790000030003','790000030103','790000030004','790000030104')
and extract(month from transaction_date) <= monthdate  and substring(analysis_code,9,1) ='0';

insert into tmp_head(id, amount)
--I. Thu nhập từ hoạt động thẻ (I)
select 
		4 as id,
		round(sum(amount),2) as amount
	from 
		tmp_head
	where id between 14 and 18;
insert into tmp_head(id, amount)
--CP vốn CCTG 
 	select 
		22 as sort_id,
		round(sum(amount),2 )as amount
	from 
		fact_txn_month_raw_data 
	where 
		account_code in ( '803000000001') 
		and extract(month from transaction_date) <= monthdate  and substring(analysis_code,9,1) ='0'
	union all 
--CP vốn TT 2
	select 
		20 as id,
		round(sum(amount),2 )as amount
	from 
		fact_txn_month_raw_data 
	where 
		account_code in ( '801000000001','802000000001')
		and extract(month from transaction_date) <= monthdate  and substring(analysis_code,9,1) ='0';
insert into tmp_head(id, amount)
--( Chi phí thuần KDV )
	select 
		5 as sort_id,
		round(sum(amount),2) as amount
	from 
		tmp_head
	where id between 20 and 22;
-- 24 -> 26
insert into tmp_head (id, amount)
--CP hoa hồng
select 
24 as id,
round(sum(amount),2) as amount
from fact_txn_month_raw_data ftmrd 
where account_code in ('816000000001','816000000002','816000000003') and 
extract(month from transaction_date) <= monthdate and substring(analysis_code,9,1) ='0'
union all
--25
--CP thuần KD khác
select 
25 as id,
round(sum(amount),2) as amount
from fact_txn_month_raw_data ftmrd 
where account_code in ('809000000002','809000000001',
'811000000001','811000000102','811000000002','811014000001',
'811037000001','811039000001','811041000001','815000000001',
'819000000002','819000000003','819000000001','790000000003',
'790000050101','790000000101','790037000001','849000000001','899000000003','899000000002','811000000101','819000060001')
and extract(month from transaction_date) <= monthdate and substring(analysis_code,9,1) ='0'
union all
--26
--DT kinh doanh
select 
26 as id,
round(sum(amount),2) as amount
from fact_txn_month_raw_data ftmrd 
where account_code in ('702000010001','702000010002','704000000001','705000000001','709000000001'
,'714000000002','714000000003','714037000001','714000000004','714014000001','715000000001'
,'715037000001','719000000001','709000000101','719000000101')
and extract(month from transaction_date) <= monthdate and substring(analysis_code,9,1) ='0';

insert into tmp_head(id,amount)
--Chi phí thuần hoạt động khác
select 
		6 as id,
		round(sum(amount),2) as amount
	from 
		tmp_head
	where id between 24 and 26;
insert into tmp_head(id, amount)
--Tổng thu nhập hoạt động
	select 
		7 as id,
		round(sum(amount),2) as amount
	from 
		tmp_head
	where id between 4 and 6;
-- 30 -> 32
insert into tmp_head (id, amount)
--CP nhân viên
select 
30 as id,
round(sum(amount),2) as amount 
from fact_txn_month_raw_data ftmrd 
where cast(account_code as text) like '85%'
and extract(month from transaction_date) <= monthdate and substring(analysis_code,9,1) ='0'

union all 
--CP quản lý
select 
31 as id,
round(sum(amount),2) as amount 
from fact_txn_month_raw_data ftmrd 
where cast(account_code as text) like '86%'
and extract(month from transaction_date) <= monthdate and substring(analysis_code,9,1) ='0'
union all 
--CP tài sản
select 
32 as id,
round(sum(amount),2) as amount 
from fact_txn_month_raw_data ftmrd 
where cast(account_code as text) like '87%'
and extract(month from transaction_date) <= monthdate and substring(analysis_code,9,1) ='0';
insert into tmp_head (id, amount)
--Tổng chi phí hoạt động
	select 
		8 as id,
		round(sum(amount),2) as amount
	from 
		tmp_head
	where id between 30 and 32;
insert into tmp_head (id, amount)
--Chi phí dự phòng
select 
		9 as id,
		round(sum(amount),2 )as amount
	from 
	fact_txn_month_raw_data ftmrd
	where 
		account_code in ('790000050001', '882200050001', '790000030001', '882200030001', '790000000001', '790000020101', '882200000001', '882200050101', '882200020101', '882200060001','790000050101', '882200030101')
	and extract(month from transaction_date) <= monthdate and substring(analysis_code,9,1) ='0';

insert into tmp_head (id, amount)
--Lợi nhuận trước thuế
	select 
		1 as id,
		round(sum(amount),2) as amount
	from 
		tmp_head 
	where id between 7 and 9;
    -- step 4: Calculate Values For tmp_area
insert into tmp_area(month,id,area_name,amount)
select 
		monthdate_key as month,
		14 as id,
		a.area_name as area_name ,
		round(a.amount,2) as amount
	from
		((with amount_area as (
			select 
				sum(amount) as amount,
				substring(analysis_code,9,1)  as area_code
			from fact_txn_month_raw_data ftmrd 
			where account_code in ('702000030002', '702000030001','702000030102')
			and extract(month from transaction_date) < 2 +1 and substring(analysis_code,9,1) <> '0'
			group by substring(analysis_code,9,1)
			),
			amount_head as (
			select 
				sum(amount) as amount,
				substring(analysis_code,9,1)  as area_code
			from fact_txn_month_raw_data ftmrd2 
			where account_code in ('702000030002', '702000030001','702000030102')
			and extract(month from transaction_date) <2+1 and substring(analysis_code,9,1) = '0'
			group by substring(analysis_code,9,1)
			),
			sum_amount as (
			select sum( amount) as sum_amount
			from amount_area 
			),
			rate_area as (
			select round(amount / sum_amount,2) as rate,area_code
			from sum_amount,amount_area 
			)
		select 	
			(a.rate*b.amount) + c.amount as amount,d.area_name
		from 
		rate_area a
		join amount_head b on 1=1
		join amount_area c on c.area_code=a.area_code
		join dim_area_code d on d.area_code=a.area_code)) a

union all		
select 
		monthdate_key as month,
		15 as id,
		a.area_name as area_name ,
		round(a.amount,2) as amount
	from
		((with amount_area as (
			select 
				sum(amount) as amount,
				substring(analysis_code,9,1)  as area_code
			from fact_txn_month_raw_data ftmrd 
			where account_code in ('702000030012', '702000030112')
			and extract(month from transaction_date) <monthdate+1 and substring(analysis_code,9,1) <> '0'
			group by substring(analysis_code,9,1)
			),
			amount_head as ( 
			select 
				sum(amount) as amount,
				substring(analysis_code,9,1)  as area_code
			from fact_txn_month_raw_data ftmrd2 
			where account_code in ('702000030012', '702000030112') and 
			extract(month from transaction_date) <monthdate+1 and substring(analysis_code,9,1) = '0'
			group by substring(analysis_code,9,1)
			),
			sum_amount as (
			select sum( amount) as sum_amount
			from amount_area 
			),
			rate_area as (
			select round(amount / sum_amount,2) as rate,area_code
			from sum_amount,amount_area 
			)
		select 	
			(a.rate*b.amount) + c.amount as amount,d.area_name
		from 
		rate_area a
		join amount_head b on 1=1
		join amount_area c on c.area_code=a.area_code
		join dim_area_code d on d.area_code=a.area_code)) a
union all
		select
		monthdate_key as month,
		16 as id,
		a.area_name as area_name ,
		round(a.amount,2) as amount
	from
		((with amount_area as (
		
			select 
				sum(amount) as amount,
				substring(analysis_code,9,1)  as area_code
			from fact_txn_month_raw_data ftmrd 
			where account_code in ('716000000001') and
			extract(month from transaction_date) <monthdate +1 and substring(analysis_code,9,1) <> '0'
			group by substring(analysis_code,9,1)
			),
			amount_head as (
			select 
				sum(amount) as amount,
				substring(analysis_code,9,1)  as area_code
			from fact_txn_month_raw_data ftmrd2 
			where account_code in ('716000000001') and 
			extract(month from transaction_date) <monthdate +1 and substring(analysis_code,9,1) = '0'
			group by substring(analysis_code,9,1)
			),
			sum_amount as (
			select sum( amount) as sum_amount
			from amount_area 
			),
			rate_area as (
			select round(amount / sum_amount,2) as rate,area_code
			from sum_amount,amount_area 
			)
		select 	
			(a.rate*b.amount) + c.amount as amount,d.area_name
		from 
		rate_area a
		join amount_head b on 1=1
		join amount_area c on c.area_code=a.area_code
		join dim_area_code d on d.area_code=a.area_code)) a
-- id 17
union all
select 
		monthdate_key as month,
		17 as id,
		a.area_name as area_name ,
		round(a.amount,2) as amount
	from
		((with amount_area as (
			select 
				sum(amount) as amount,
				substring(analysis_code,9,1)  as area_code
			from fact_txn_month_raw_data ftmrd 
			where account_code in ('719000030002') and 
			extract(month from transaction_date) <monthdate +1 and substring(analysis_code,9,1) <> '0'
			group by substring(analysis_code,9,1)
			),
			amount_head as (
			select 
				sum(amount) as amount,
				substring(analysis_code,9,1)  as area_code
			from fact_txn_month_raw_data ftmrd2 
			where account_code in ('719000030002') and 
			extract(month from transaction_date) <monthdate + 1 and substring(analysis_code,9,1) = '0'
			group by substring(analysis_code,9,1)
			),
			sum_amount as (
			select sum( amount) as sum_amount
			from amount_area 
			),
			rate_area as (
			select round(amount / sum_amount,2) as rate,area_code
			from sum_amount,amount_area 
			)
		select 	
			(a.rate*b.amount) + c.amount as amount,d.area_name
		from 
		rate_area a
		join amount_head b on 1=1
		join amount_area c on c.area_code=a.area_code
		join dim_area_code d on d.area_code=a.area_code)) a
-- id 18
union all
select 
		monthdate_key as month,
		18 as id,
		a.area_name as area_name ,
		round(a.amount,2) as amount
	from
		((with amount_area as (
			select 
				sum(amount) as amount,
				substring(analysis_code,9,1)  as area_code
			from fact_txn_month_raw_data ftmrd 
			where account_code in ('719000030003','719000030103','790000030003','790000030103','790000030004','790000030104') and
			extract(month from transaction_date) < monthdate+1 and substring(analysis_code,9,1) <> '0'
			group by substring(analysis_code,9,1)
			),
			amount_head as (
			select 
				sum(amount) as amount,
				substring(analysis_code,9,1)  as area_code
			from fact_txn_month_raw_data ftmrd2 
			where account_code in ('719000030003','719000030103','790000030003','790000030103','790000030004','790000030104') and 
			extract(month from transaction_date) < monthdate+1 and substring(analysis_code,9,1) = '0'
			group by substring(analysis_code,9,1)
			),
			sum_amount as (
			select sum( amount) as sum_amount
			from amount_area 
			),
			rate_area as (
			select round(amount / sum_amount,2) as rate,area_code
			from sum_amount,amount_area 
			)
		select 	
			(a.rate*b.amount) + c.amount as amount,d.area_name
		from 
		rate_area a
		join amount_head b on 1=1
		join amount_area c on c.area_code=a.area_code
		join dim_area_code d on d.area_code=a.area_code)) a;
insert into tmp_area (month,id,area_name,amount)
(select
	monthdate_key as month,
		4 as id,
		area_name,
		round(sum(amount),2) as amount
	from tmp_area
	where id between 14 and 18
	group by area_name);
		
		
INSERT INTO tmp_area (month,id, area_name, amount)
-- ID = 24
SELECT 	
	monthdate_key as month,
    24 AS id,
    a.area_name AS area_name,
    ROUND(a.amount, 2) AS amount
FROM (
    WITH 
    amount_area AS (
        SELECT 
            SUM(amount) AS amount,
            SUBSTRING(analysis_code, 9, 1) AS area_code
        FROM fact_txn_month_raw_data
        where account_code in ('816000000001','816000000002','816000000003') and 
        extract(month from transaction_date) <monthdate+1 and substring(analysis_code,9,1) <> '0'
        GROUP BY SUBSTRING(analysis_code, 9, 1)
    ),
    amount_head AS (
        SELECT 
            SUM(amount) AS amount,
            SUBSTRING(analysis_code, 9, 1) AS area_code
        FROM fact_txn_month_raw_data
        WHERE account_code IN ('816000000001', '816000000002', '816000000003') and
        extract(month from transaction_date) <monthdate+1 and substring(analysis_code,9,1) = '0'
        GROUP BY SUBSTRING(analysis_code, 9, 1)
    ),
    sum_amount AS (
        SELECT SUM(amount) AS sum_amount
        FROM amount_area
    ),
    rate_area AS (
        SELECT 
            ROUND(amount / sum_amount, 2) AS rate,
            area_code
        FROM sum_amount, amount_area
    )
    SELECT 
        (a.rate * b.amount) + c.amount AS amount,
        d.area_name
    FROM rate_area a
    JOIN amount_head b ON 1=1
    JOIN amount_area c ON c.area_code = a.area_code
    JOIN dim_area_code d ON d.area_code = a.area_code
) a
UNION ALL

-- ID = 25
SELECT 
	monthdate_key as month,
    25 AS id,
    a.area_name AS area_name,
    ROUND(a.amount, 2) AS amount
FROM (
    WITH 
    amount_area AS (
        SELECT 
            SUM(amount) AS amount,
            SUBSTRING(analysis_code, 9, 1) AS area_code
        FROM fact_txn_month_raw_data
        WHERE account_code IN (
            '809000000002', '809000000001', '811000000001', '811000000102', 
            '811000000002', '811014000001', '811037000001', '811039000001',
            '811041000001', '815000000001', '819000000002', '819000000003', 
            '819000000001', '790000000003', '790000050101', '790000000101',
            '790037000001', '849000000001', '899000000003', '899000000002',
            '811000000101', '819000060001') 
        and extract(month from transaction_date) <monthdate+1 and substring(analysis_code,9,1) <> '0'
        GROUP BY SUBSTRING(analysis_code, 9, 1)
    ),
    amount_head AS (
        SELECT 
            SUM(amount) AS amount,
            SUBSTRING(analysis_code, 9, 1) AS area_code
        FROM fact_txn_month_raw_data
        WHERE account_code IN (
            '809000000002', '809000000001', '811000000001', '811000000102', 
            '811000000002', '811014000001', '811037000001', '811039000001',
            '811041000001', '815000000001', '819000000002', '819000000003', 
            '819000000001', '790000000003', '790000050101', '790000000101',
            '790037000001', '849000000001', '899000000003', '899000000002',
            '811000000101', '819000060001') 
        and extract(month from transaction_date) <monthdate +1 and substring(analysis_code,9,1) = '0'
        GROUP BY SUBSTRING(analysis_code, 9, 1)
    ),
    sum_amount AS (
        SELECT SUM(amount) AS sum_amount
        FROM amount_area
    ),
    rate_area AS (
        SELECT 
            ROUND(amount / sum_amount, 2) AS rate,
            area_code
        FROM sum_amount, amount_area
    )
    SELECT 
        (a.rate * b.amount) + c.amount AS amount,
        d.area_name
    FROM rate_area a
    JOIN amount_head b ON 1=1
    JOIN amount_area c ON c.area_code = a.area_code
    JOIN dim_area_code d ON d.area_code = a.area_code
) a

UNION ALL

-- ID = 26
SELECT 
	monthdate_key as month,
    26 AS id,
    a.area_name AS area_name,
    ROUND(a.amount, 2) AS amount
FROM (
    WITH 
    amount_area AS (
        SELECT 
            SUM(amount) AS amount,
            SUBSTRING(analysis_code, 9, 1) AS area_code
        FROM fact_txn_month_raw_data
        WHERE account_code IN (
            '702000010001', '702000010002', '704000000001', '705000000001', 
            '709000000001', '714000000002', '714000000003', '714037000001', 
            '714000000004', '714014000001', '715000000001', '715037000001', 
            '719000000001', '709000000101', '719000000101') 
        and extract(month from transaction_date) <monthdate+1 and substring(analysis_code,9,1) <> '0'
        GROUP BY SUBSTRING(analysis_code, 9, 1)
    ),
    amount_head AS (
        SELECT 
            SUM(amount) AS amount,
            SUBSTRING(analysis_code, 9, 1) AS area_code
        FROM fact_txn_month_raw_data
        WHERE account_code IN (
            '702000010001', '702000010002', '704000000001', '705000000001', 
            '709000000001', '714000000002', '714000000003', '714037000001', 
            '714000000004', '714014000001', '715000000001', '715037000001', 
            '719000000001', '709000000101', '719000000101') 
        and extract(month from transaction_date) <monthdate+1 and substring(analysis_code,9,1) = '0'
        GROUP BY SUBSTRING(analysis_code, 9, 1)
    ),
    sum_amount AS (
        SELECT SUM(amount) AS sum_amount
        FROM amount_area
    ),
    rate_area AS (
        SELECT 
            ROUND(amount / sum_amount, 2) AS rate,
            area_code
        FROM sum_amount, amount_area
    )
    SELECT 
        (a.rate * b.amount) + c.amount AS amount,
        d.area_name
    FROM rate_area a
    JOIN amount_head b ON 1=1
    JOIN amount_area c ON c.area_code = a.area_code
    JOIN dim_area_code d ON d.area_code = a.area_code
) a;
insert into tmp_area (month,id,area_name,amount)
(select
		monthdate_key as month,
		6 as id,
		area_name as area_name ,
		round(sum(amount),2) as amount
	from tmp_area
	where id between 24 and 26
	group by area_name);
insert into tmp_area (month,id,area_name,amount)
	select 
	monthdate_key as month,
	20 as id,
	area_name as area_name ,
	round(amount,2) as amount
	from 
	(with amount_head as (
	---- Tính amount chưa phân bổ của từng khu vực theo tiêu chí sort_id =20
		select 
			sum(amount) as amount,
			substring(analysis_code,9,1)  as area_code
		from fact_txn_month_raw_data  
		where account_code in ('801000000001','802000000001')  and extract(month from transaction_date) < monthdate +1 and substring(analysis_code,9,1) = '0'
		group by substring(analysis_code,9,1)
	),
		rate as (
		select area_code, du_no/sum_du_no as rate
		from tmp_table 
		join 
			(select sum(du_no) as sum_du_no
			 from tmp_table ) on 1=1 
	)
	select b.amount* a.rate as amount , c.area_name
	from rate a
	join amount_head b on 1=1
	join dim_area_code  c on c.area_code =a.area_code)
--
	union all 
	(select 
		monthdate_key as month,
		22 as id,
		area_name as area_name ,
		round(amount,2) as value
	from 
	(with amount_head as (
		select 
			sum(amount) as amount,
			substring(analysis_code,9,1)  as area_code
		from fact_txn_month_raw_data 
		where account_code in ( '803000000001') and extract(month from transaction_date) <monthdate +1 and substring(analysis_code,9,1) = '0'
		group by substring(analysis_code,9,1)
	),
		rate as (
		select area_code, du_no/sum_du_no as rate
		from tmp_table 
		join 
			(select sum(du_no) as sum_du_no
			 from tmp_table ) on 1=1 
	)
	select b.amount* a.rate as amount , c.area_name
	from rate a
	join amount_head b on 1=1
	join dim_area_code c on c.area_code =a.area_code));
	insert into tmp_area (month,id,area_name,amount)
	(select
		monthdate_key as month,
		5 as id ,
		area_name,
		round(sum(amount),2) as amount
	from tmp_area
	where id between 20 and 22
	group by area_name);
	insert into tmp_area (month,id,area_name,amount)
	select 
		monthdate_key as month,
		30 as id,
		area_name as area_name ,
		round(amount,2) as amount
	from
	(with amount_area as (
		-- Tính amount chưa phân bổ của từng khu vực theo tiêu chí sort_id =30
		select 
			sum(amount) as amount,
			substring(analysis_code,9,1)  as area_code
		from fact_txn_month_raw_data act
		where CAST(account_code AS TEXT) LIKE '85%'  and extract(month from transaction_date) <monthdate +1 and substring(analysis_code,9,1) <> '0'
		group by substring(analysis_code,9,1)
		),
		-- Tính amount của head để phân bổ về khu vực 
		amount_head as (
		select 
			sum(amount) as amount,
			substring(analysis_code,9,1)  as area_code
		from fact_txn_month_raw_data 
		where CAST(account_code AS TEXT) LIKE '85%'  and extract(month from transaction_date) <monthdate +1 and substring(analysis_code,9,1) = '0'
		group by substring(analysis_code,9,1)
		),
		count_sale as(
		select count(distinct sale_name) as cnt_sale,area_name
		from fact_kpi_data_final 
		group by area_name),
		rate as(
			select 
				a.cnt_sale/ b.sum as rate , c.area_code 
			from count_sale a
			join (
				select 
					sum(cnt_sale) 
				from count_sale 
			) b on 1=1
			join dim_area_code  c on c.area_name  =a.area_name 
		)	
	select 	
		(a.rate*b.amount) + c.amount as amount,d.area_name
	from 
	rate a
	join amount_head b on 1=1
	join amount_area c on c.area_code=a.area_code
	join dim_area_code  d on a.area_code=d.area_code)
	union all
	(select 
		monthdate_key as month,
		31 as id,
		area_name as area_name ,
		round(amount,2) as amount
	from
	(with amount_area as (
	-- Tính amount chưa phân bổ của từng khu vực theo tiêu chí sort_id =31
		select 
			sum(amount) as amount,
			substring(analysis_code,9,1)  as area_code
		from fact_txn_month_raw_data act
		where CAST(account_code AS TEXT) LIKE '86%'  and extract(month from transaction_date) <monthdate +1 and substring(analysis_code,9,1) <> '0'
		group by substring(analysis_code,9,1)
		),
		-- Tính amount của head để phân bổ về khu vực 
		amount_head as (
		select 
			sum(amount) as amount,
			substring(analysis_code,9,1)  as area_code
		from fact_txn_month_raw_data act
		where CAST(account_code AS TEXT) LIKE '86%'  and extract(month from transaction_date) <monthdate +1 and substring(analysis_code,9,1) = '0'
		group by substring(analysis_code,9,1)
		),
		count_sale as(
		select count(distinct sale_name) as cnt_sale,area_name
		from fact_kpi_data_final 
		group by area_name),
		rate as(
			select 
				a.cnt_sale/ b.sum as rate , c.area_code 
			from count_sale a
			join (
				select 
					sum(cnt_sale) 
				from count_sale 
			) b on 1=1
			join dim_area_code c on c.area_name  =a.area_name 
		)	
	select 	
		(a.rate*b.amount) + c.amount as amount,d.area_name
	from 
	rate a
	join amount_head b on 1=1
	join amount_area c on c.area_code=a.area_code
	join dim_area_code d on d.area_code=a.area_code))
	union all
	(select 
		monthdate_key as month,
		32 as id,
		area_name as area_name ,
		round(amount,2) as amount
	from
	(with amount_area as (
	-- Tính amount chưa phân bổ của từng khu vực theo tiêu chí sort_id =31
		select 
			sum(amount) as amount,
			substring(analysis_code,9,1)  as area_code
		from fact_txn_month_raw_data 
		where CAST(account_code AS TEXT) LIKE '87%'  and extract(month from transaction_date) <monthdate + 1 and substring(analysis_code,9,1) <> '0'
		group by substring(analysis_code,9,1)
		),
		amount_head as (
		select 
			sum(amount) as amount,
			substring(analysis_code,9,1)  as area_code
		from fact_txn_month_raw_data act
		where CAST(account_code AS TEXT) LIKE '87%'  and extract(month from transaction_date) < monthdate + 1 and substring(analysis_code,9,1) = '0'
		group by substring(analysis_code,9,1)
		),
		count_sale as(
		select count(distinct sale_name) as cnt_sale,area_name
		from fact_kpi_data_final 
		group by area_name),
		rate as(
			select 
				a.cnt_sale/ b.sum as rate , c.area_code 
			from count_sale a
			join (
				select 
					sum(cnt_sale) 
				from count_sale 
			) b on 1=1
			join dim_area_code  c on c.area_name  =a.area_name 
		)	
	select 	
		(a.rate*b.amount) + c.amount as amount,d.area_name 
	from 
	rate a
	join amount_head b on 1=1
	join amount_area c on c.area_code=a.area_code
	join dim_area_code d on d.area_code=a.area_code));
	insert into tmp_area (month,id,area_name,amount)
	(select
		monthdate_key as month,
		8 as id ,
		area_name,
		sum(amount) as amount
	from tmp_area
	where id between 30 and 32
	group by area_name);
	insert into tmp_area (month,id,area_name,amount)
	(select
		monthdate_key as month,
		7 as id ,
		area_name,
		round(sum(amount),2) as amount
	from tmp_area
	where id between 4 and 6
	group by area_name);
	insert into tmp_area (month,id,area_name,amount)
	select 
		monthdate_key as month,
		9 as id ,
		area_name,
		round(amount,2) as amount
	from
	(with amount_area as (
		select 
			sum(amount) as amount,
			substring(analysis_code,9,1)  as area_code
		from fact_txn_month_raw_data 
		where account_code in ('790000050001', '882200050001', '790000030001', '882200030001', '790000000001', '790000020101', '882200000001', '882200050101', '882200020101', '882200060001','790000050101', '882200030101') and extract(month from transaction_date) <monthdate +1 and substring(analysis_code,9,1) <> '0'
		group by substring(analysis_code,9,1)
		),
		amount_head as (
		select 
			sum(amount) as amount,
			substring(analysis_code,9,1)  as area_code
		from fact_txn_month_raw_data
		where account_code in ('790000050001', '882200050001', '790000030001', '882200030001', '790000000001', '790000020101', '882200000001', '882200050101', '882200020101', '882200060001','790000050101', '882200030101') and extract(month from transaction_date) <  monthdate +1 and substring(analysis_code,9,1) = '0'
		group by substring(analysis_code,9,1)
		),
		sum_amount as (
		select sum( amount) as sum_amount
		from amount_area 
		),
		rate_area as (
		select round(amount / sum_amount,2) as rate,area_code
		from sum_amount,amount_area 
		)
	select 	
		(a.rate*b.amount) + c.amount as amount,d.area_name
	from 
	rate_area a
	join amount_head b on 1=1
	join amount_area c on c.area_code=a.area_code
	join dim_area_code d on d.area_code=a.area_code);
	insert into tmp_area (month,id,area_name,amount)
	select 
		monthdate_key as month,
		2 as id ,
		area_name,
		cnt_sale as amount
	from 
		(select 
			count(distinct sale_name) as cnt_sale,
			b.area_name
		from fact_kpi_data_final  a
		join dim_area_code b on a.area_name=b.area_name
		group by b.area_name);
	insert into tmp_area (month,id,area_name,amount)
	(select
		monthdate_key as month,
		1 as id ,
		area_name,
		sum(amount) as amount
	from tmp_area
	where id between 7 and 9
	group by area_name);
	insert into tmp_area (month,id,area_name,amount)
	(select
		monthdate_key as month,
		10 as id,
		a.area_name,
		round(b.amount_id8/a.amount_id7*(-100),2) as amount
	from 
		(select 
			amount as amount_id7,
			area_name
		from tmp_area
		where id = 7) a
	join 
	(select 
			amount as amount_id8,
			area_name
		from tmp_area
		where id = 8) b  on a.area_name= b.area_name 
	union all 
	(select
		monthdate_key as month,
		11 as id,
		a.area_name,
		round(a.amount_id1/(b.amount_id4+c.amount_id25)*(100),2) as amount
	from 
		(select 
			amount as amount_id1,
			area_name
		from tmp_area
		where id = 1) a
	join 
	(select 
			amount as amount_id4,
			area_name
		from tmp_area
		where id = 4) b  on a.area_name=b.area_name
	join 
	(select 
			amount as amount_id25,
			area_name
		from tmp_area
		where id = 26) c  on a.area_name=c.area_name)
	union all 
	(select
		monthdate_key as month,
		12 as id,
		a.area_name,
		round(a.amount_id1/b.amount_id5*(-100),2) as amount
	from 
		(select 
			amount as amount_id1,area_name
		from tmp_area
		where id = 1) a
	join 
	(select 
			amount as amount_id5,
			area_name
		from tmp_area 
		where id = 5) b  on a.area_name=b.area_name)
	union all 
	(select
		monthdate_key as month,
		13 as id,
		a.area_name,
		round(a.amount_id1/b.amount_id2,2) as amount
	from 
		(select 
			amount as amount_id1,
			area_name
		from tmp_area
		where id = 1) a
	join 
	(select 
			amount as amount_id2,
			area_name
		from tmp_area
		where id = 2) b  on a.area_name=b.area_name));
	insert into  tmp_report(id,month_key)
	SELECT 
    distinct id,month as month_key
FROM 
    tmp_area;
-- step 5: Target fact_profit_loss_area_by_monthly, fact_ranking_asm
-- insert bang fact_report_tong_hop
	for i in 1 .. array_length(area_arr,1)
	loop
		for j in 1.. sort_id_max
			loop
				query :=
					format('
						update tmp_report b
						set %I=
							(select 
								amount
							from tmp_area a
							where a.id= %L and a.area_name= %L)
						where b.id = %L
							',area_arr[i],j,area_name_arr[i],j);
				execute query;
			end loop;
	end loop;
--FOR i IN 1 .. array_length(area_arr, 1) LOOP
--    FOR j IN 1 .. sort_id_max LOOP
--        EXECUTE format(
--            'UPDATE tmp_report b 
--             SET %I = (SELECT amount 
--                       FROM tmp_area a 
--                       WHERE a.id = %L AND a.area_name = %L) 
--             WHERE b.id = %L',
--            area_arr[i], j, area_name_arr[i], j
--        );
--    END LOOP;
--END LOOP;
WITH ordered_tonghop AS (
    SELECT *, ROW_NUMBER() OVER () AS rn
    FROM dim_report_item
)
INSERT INTO fact_profit_loss_area_by_monthly (month_key,id, information, Head, dong_bac_bo, tay_bac_bo, db_song_hong, bac_trung_bo, nam_trung_bo, tay_nam_bo, dong_nam_bo)
SELECT 	
	b.month_key,
    a.id,  
    a.information,
    c.amount AS Head,
    b.dong_bac_bo,
    b.tay_bac_bo,
    b.db_song_hong,
    b.bac_trung_bo,
    b.nam_trung_bo,
    b.tay_nam_bo,
    b.dong_nam_bo
FROM ordered_tonghop a
JOIN tmp_report b ON a.id = b.id
LEFT JOIN tmp_head c ON c.id = a.id
ORDER BY a.rn;

	INSERT INTO fact_ranking_asm(
    month_key, area_code, area_name, email, tong_diem, rank_final, 
    ltn_avg, rank_ltn_avg, psdn_avg, rank_psdn_avg, approval_rate_avg, 
    rank_approval_rate_avg, npl_truoc_wo_luy_ke, rank_npl_truoc_wo_luy_ke, 
    diem_quy_mo, rank_ptkd, cir, rank_cir, margin, rank_margin, hs_von, 
    rank_hs_von, hsbq_nhan_su, rank_hsbq_nhan_su, diem_fin, rank_fin
	)
	SELECT 
    month_key, area_code, area_name, email, tong_diem, rank_final, 
    ltn_avg, rank_ltn_avg, psdn_avg, rank_psdn_avg, approval_rate_avg, 
    rank_approval_rate_avg, npl_truoc_wo_luy_ke, rank_npl_truoc_wo_luy_ke, 
    diem_quy_mo, rank_ptkd, cir, rank_cir, margin, rank_margin, hs_von, 
    rank_hs_von, hsbq_nhan_su, rank_hsbq_nhan_su, diem_fin, rank_fin
	from 	
	(select 
		a.*,
		diem_quy_mo + diem_fin as tong_diem,
		rank() over(order by diem_quy_mo + diem_fin) as rank_final
	from 
		(select 
				a.* ,
				rank() over(order by diem_quy_mo) as rank_ptkd,
				b.amount as cir,
				b.rank_cir as rank_cir,
				c.amount as margin,
				c.rank_margin as rank_margin,
				d.amount as hs_von,
				d.rank_hs_von as rank_hs_von,
				e.amount as hsbq_nhan_su,
				e.rank_hsbq_nhan_su as rank_hsbq_nhan_su ,
				rank_cir + rank_margin + rank_hs_von + rank_hsbq_nhan_su as diem_fin,
				rank() over(order by rank_cir + rank_margin + rank_hs_von + rank_hsbq_nhan_su) as rank_fin
				from 
					(select 
						monthdate_key as month_key,
						a.area_code as area_code,
						a.area_name as area_name,
						a.email as email,
						b.ltn_avg as ltn_avg,
						b.rank_ltn_avg as rank_ltn_avg,
						c.psdn_avg as psdn_avg,
						c.rank_psdn_avg as rank_psdn_avg,
						d.approval_rate_avg  as approval_rate_avg,
						d.rank_approval_rate_avg as rank_approval_rate_avg,
						e.rate as npl_truoc_wo_luy_ke,
						rank() over(order by rate ) as rank_npl_truoc_wo_luy_ke, 
						b.rank_ltn_avg + c.rank_psdn_avg + d.rank_approval_rate_avg + rank() over(order by rate ) as diem_quy_mo
					from 
						(select distinct 
--						 	a.month_key,
							a.email,
							a.area_name,
							b.area_code 
						from fact_kpi_data_final  a
						join dim_area_code b on a.area_name = b.area_name ) a
					join 
						(select
							ltn_avg,
							rank() over(order by ltn_avg desc) as rank_ltn_avg,
							email,
							area_name
						from 
							(
							SELECT 
    CASE 
        WHEN monthdate = 1 THEN jan_LTN
        WHEN monthdate = 2 THEN (jan_LTN + feb_LTN)/2
        WHEN monthdate = 3 THEN (jan_LTN + feb_LTN + mar_LTN)/3
        WHEN monthdate = 4 THEN (jan_LTN + feb_LTN+ mar_LTN + apr_LTN)/4
        WHEN monthdate = 5 then (jan_LTN + feb_LTN + mar_LTN + apr_LTN + may_LTN)/5
    END AS ltn_avg,
    email,
    area_name
FROM fact_kpi_data_final 
group by sale_name, email,area_name,ltn_avg
							)
						)  b on a.email=b.email and a.area_name=b.area_name 
					join 
						(select
							psdn_avg,
							rank() over(order by psdn_avg desc) as rank_psdn_avg,
							email,
							area_name
						from 
							(SELECT 
    CASE 
        WHEN monthdate = 1 THEN jan_PSDN
        WHEN monthdate = 2 THEN (jan_PSDN + feb_PSDN)/2
        WHEN monthdate = 3 THEN (jan_PSDN + feb_PSDN + mar_PSDN)/3
        WHEN monthdate = 4 THEN (jan_PSDN + feb_PSDN + mar_PSDN + apr_PSDN)/4
        WHEN monthdate = 5 then (jan_PSDN + feb_PSDN + mar_PSDN + apr_PSDN + may_PSDN)/5
    END AS psdn_avg,
    email,
    area_name
FROM fact_kpi_data_final 
 group by sale_name, email,area_name,psdn_avg 
--						
							)
						)  c on a.email=c.email and a.area_name=c.area_name 
					join 
						(select
							approval_rate_avg ,
							rank() over(order by approval_rate_avg  desc) as rank_approval_rate_avg ,
							email,
							area_name
						from 
							(SELECT 
    CASE 
        WHEN monthdate = 1 THEN (jan_AR)
        WHEN monthdate = 2 THEN (jan_AR + feb_AR)/2
        WHEN monthdate = 3 THEN (jan_AR + feb_AR + mar_AR)/3
        WHEN monthdate = 4 THEN (jan_AR + feb_AR + mar_AR + apr_AR)/4
        WHEN monthdate = 5 then (jan_AR + feb_AR + mar_AR + apr_AR + may_AR)/5
    END AS approval_rate_avg,
    email,
    area_name 
FROM fact_kpi_data_final 
group by sale_name, email,area_name,approval_rate_avg
							)
						)  d on a.email=d.email and a.area_name=d.area_name 
					join 
						tmp_table e on e.area_code =a.area_code) a
				join 
					(select
						amount, 
						area_name,
						rank() over(order by amount asc) as rank_cir
					from tmp_area
					where id=10) b on b.area_name=a.area_name
				join  
					(select
						amount, 
						area_name,
						rank() over(order by amount desc) as rank_margin
					from tmp_area
					where id=11) c on c.area_name=a.area_name
				join 
					(select
						amount, 
						area_name,
						rank() over(order by amount desc) as rank_hs_von
					from tmp_area  
					where id=12) d on d.area_name=a.area_name
					join 
					(select
						amount, 
						area_name,
						rank() over(order by amount desc) as rank_hsbq_nhan_su
					from tmp_area
					where id=13) e on e.area_name=a.area_name) a);
end;
$$;
call backdate_month_prc(2);
select * from dim_report_item 
select * from fact_ranking_asm fka 
select * from fact_profit_loss_area_by_monthly fplabm 



select area_name,count(email) from fact_ranking_asm fra 
group by area_name;