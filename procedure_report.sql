    -- Creater Information 
    -- ---------------------
   	-- Procedure name: backdate_month_prc 
    -- Author: Nguyễn An Đức
    -- Created : 2025

    -- ---------------------


    -- ---------------------
    -- SUMMARY Processing Stream
    -- ---------------------
    -- step 1: Declare Variables
    -- step 2: Execute SQL Statements And Process Logic
    -- step 3: Calculate Values For tmp_head
    -- step 4: Calculate Values For tmp_area
    -- step 5: Target fact_profit_loss_area_by_monthly, fact_ranking_asm
CREATE OR REPLACE PROCEDURE final_project.report_asm_ranking(IN monthkey_input integer DEFAULT NULL::integer)
 LANGUAGE plpgsql
AS $procedure$
declare 
	--Các biến khai báo cần phải tổng hợp
	vmonthkey int;
	current_month int:=extract(month from current_Date)::int;
	current_year int:=extract(year from current_Date)::int;
	--Các biến ghi nhận thời gian hoàn thành procedure
   	v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_is_successful CHAR(1) := 'Y';
    v_error_log TEXT;
    v_log_id INT;
BEGIN
    -- Bước 1: Ghi nhận thời gian bắt đầu procedure
	v_start_time := CURRENT_TIMESTAMP;
	insert into log_tracking(procedure_name, start_time, is_successful)
	values ('report_asm_ranking', v_start_time, v_is_successful)
	returning log_id into v_log_id;

	-- Bước 2: Kiểm tra nếu tháng truyền vào là null sẽ lấy vmonthkey = Tháng hiện tại - 1
	if monthkey_input is null and current_month = 1
		then vmonthkey := (current_year - 1)*100 + 12;
	elseif monthkey_input is null and current_month != 1
		then vmonthkey := current_year*100 + current_month - 1;
	else vmonthkey := monthkey_input;
	end if;

	-- Bước 3: xoá dữ liệu report_monthly tại tháng vmonthkey
	delete from report_monthly where month_key = vmonthkey;

	-- Bước 4: insert dữ liệu theo từng tiêu chí vào bảng
	insert into report_monthly  
		(month_key, index_id, amount, area_code)
		-- Lãi trong hạn
		select 
			a.month_key,
			a.index_id,
			-- Lãi trong hạn = lãi trong hạn của riêng khu vực + phần lãi trong hạn của HEAD được chia cho từng khu vực theo tỷ lệ dư nợ của từng khu vực 
			coalesce(a.lai_trong_han + b.dnck_rate_n1*(
											select 
												sum(amount)  as lai_trong_han
											 from fact_txn_month_raw_data ftmrd2
											 where 
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
											 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey 
											 	and index_id = 3 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_trong_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_trong_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
				and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 3
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	vmonthkey as month_key,
			    area_code,
				sum(outstanding_principal)/x.avg_dnck_n1 as dnck_rate_n1
			from fact_kpi_month_raw_data fkmrd2 
			join 
			    (
				select 
		    		sum(outstanding_principal) as avg_dnck_n1
		    	from fact_kpi_month_raw_data fkmrd 
		    	where 
		    		kpi_month >= (vmonthkey/100) + 1
		    		and kpi_month <= vmonthkey 
		    		and (max_bucket = 1 or max_bucket is null) 
	    		) x
	    		on 
	    			fkmrd2.kpi_month >= (vmonthkey/100) + 1 
	    			and fkmrd2.kpi_month <= vmonthkey 
	    			and (max_bucket = 1 or max_bucket is null)
			    group by
			    	x.avg_dnck_n1,
			    	area_code
			   		) b
		on a.area_code = b.area_code
		-- Lãi quá hạn
		union all
		select 
			a.month_key,
			a.index_id,
			coalesce(a.lai_qua_han + b.dnck_rate_n2*(
											select 
												sum(amount)  as lai_qua_han
											 from fact_txn_month_raw_data ftmrd2
											 where 
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
												and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
											 	and index_id = 4 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_qua_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_qua_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
			 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 4
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	vmonthkey as month_key,
			   area_code,
				sum(outstanding_principal)/x.avg_dnck_n2 as dnck_rate_n2
			from fact_kpi_month_raw_data fkmrd2 
			join 
			    (
				select 
		    		sum(outstanding_principal) as avg_dnck_n2
		    	from fact_kpi_month_raw_data fkmrd 
		    	where 
					kpi_month >= (vmonthkey/100) + 1
		    		and kpi_month <= vmonthkey  
		    		and max_bucket = 2
	    		) x
	    		on 
	    			fkmrd2.kpi_month >= (vmonthkey/100) + 1 
	    			and fkmrd2.kpi_month <= vmonthkey 
	    			and fkmrd2.max_bucket = 2
			    group by
			    	x.avg_dnck_n2,
			    	area_code
			   		) b
		on a.area_code = b.area_code
		--Phí bảo hiểm
		union all
		select 
			a.month_key,
			a.index_id,
			coalesce(a.lai_qua_han + b.psdn_rate*(
											select 
												sum(amount)  as lai_qua_han
											 from fact_txn_month_raw_data ftmrd2
											 where 
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
											 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey 
											 	and index_id = 5 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_qua_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_qua_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
			 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 5
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	vmonthkey as month_key,
			    area_code,
				sum(psdn)/x.avg_psdn as psdn_rate
			from fact_kpi_month_raw_data fkmrd2 
			join 
			    (
				select 
		    		sum(psdn) as avg_psdn
		    	from fact_kpi_month_raw_data fkmrd 
		    	where 
		    		kpi_month >= (vmonthkey/100) + 1
		    		and kpi_month <= vmonthkey
	    		) x
	    		on 
	    			fkmrd2.kpi_month >= (vmonthkey/100) + 1 
	    			and fkmrd2.kpi_month <= vmonthkey
			    group by
			    	x.avg_psdn,
			    	area_code
			   		) b
		on a.area_code = b.area_code
		--Phí tăng hạn mức
		union all
		select 
			a.month_key,
			a.index_id,
			coalesce(a.lai_trong_han + b.dnck_rate_n1*(
											select 
												sum(amount)  as lai_trong_han
											 from fact_txn_month_raw_data ftmrd2
											 where 
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
											 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey 
											 	and index_id = 6 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_trong_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_trong_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
			 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 6
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	vmonthkey as month_key,
			    area_code,
				sum(outstanding_principal)/x.avg_dnck_n1 as dnck_rate_n1
			from fact_kpi_month_raw_data fkmrd2 
			join 
			    (
				select 
		    		sum(outstanding_principal) as avg_dnck_n1
		    	from fact_kpi_month_raw_data fkmrd 
		    	where 
		    		kpi_month >= (vmonthkey/100) + 1
		    		and kpi_month <= vmonthkey 
		    		and (max_bucket = 1 or max_bucket is null) 
	    		) x
	    		on 
	    			fkmrd2.kpi_month >= (vmonthkey/100) + 1 
	    			and fkmrd2.kpi_month <= vmonthkey 
	    			and (max_bucket = 1 or max_bucket is null)
			    group by
			    	x.avg_dnck_n1,
			    	area_code
			   		) b
		on a.area_code = b.area_code
		--Phí thanh toán chậm, thu từ ngoại bảng, khác…
		union all	
		select 
			a.month_key,
			a.index_id,
			coalesce(a.lai_trong_han + b.dnck_rate_n2_5*(
											select 
												sum(amount)  as lai_trong_han
											 from fact_txn_month_raw_data ftmrd2
											 where
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
											 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey 
											 	and index_id = 7 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_trong_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_trong_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
			 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 7
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	vmonthkey as month_key,
				area_code,
				sum(outstanding_principal)/x.avg_dnck_n2_5 as dnck_rate_n2_5
			from fact_kpi_month_raw_data fkmrd2 
			join 
			    (
				select 
		    		sum(outstanding_principal) as avg_dnck_n2_5
		    	from fact_kpi_month_raw_data fkmrd 
		    	where 
		    		kpi_month >= (vmonthkey/100) + 1
		    		and kpi_month <= vmonthkey and max_bucket >= 2
	    		) x
	    		on
	    			fkmrd2.kpi_month >= (vmonthkey/100) + 1 
	    			and fkmrd2.kpi_month <= vmonthkey and max_bucket >= 2
			    group by
			    	x.avg_dnck_n2_5,
			    	area_code
			   		) b
		on a.area_code = b.area_code;
		--Thu nhập từ hoạt động thẻ, lấy tổng các chỉ số ở 3,4,5,6,7 đã nhập vào report_monthly ở trên
	insert into report_monthly  
		(month_key, index_id, amount, area_code)
		select 
			vmonthkey as month_key,
			2 as index_id,
			sum
				(
				case 
					when index_id in (3,4,5,6,7) then amount
				end
				) as amount,
			area_code
		from report_monthly 
		where month_key = vmonthkey
		group by area_code
		--Chi phí vốn CCTG
		union all
		select 
			b.month_key,
			a.index_id,
			b.dnck_rate*a.phi_cctg/1000000 as amount,
			b.area_code
		from
			(
			select 
			 	vmonthkey as month_key,
			    area_code,
				sum(outstanding_principal)/x.avg_dnck as dnck_rate
			from fact_kpi_month_raw_data fkmrd2 
			join 
			    (
				select 
		    		sum(outstanding_principal) as avg_dnck
		    	from fact_kpi_month_raw_data fkmrd 
		    	where 
		    		kpi_month >= (vmonthkey/100) + 1
		    		and kpi_month <= vmonthkey
	    		) x
	    		on 
					fkmrd2.kpi_month >= (vmonthkey/100) + 1 
	    			and fkmrd2.kpi_month <= vmonthkey
			    group by
			    	x.avg_dnck,
			    	area_code
			   		) b
			left join 
			(
				select 
					vmonthkey as month_key,
					index_id,
					sum(amount)  as phi_cctg,
					area_code
				 from fact_txn_month_raw_data ftmrd2
				 where 
				 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
				 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
				 	and index_id = 12
				 group by
				 	index_id,
				 	area_code
			 ) a
		on 1=1
		union all
				select 
					vmonthkey as month_key,
					index_id,
					sum(amount)/1000000  as phi_cctg,
					area_code
				 from fact_txn_month_raw_data ftmrd2
				 where
				 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
				 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
				 	and index_id = 12
				 group by
				 	index_id,
				 	area_code
		-- Chi phí vốn TT1
		union all
		select 
			b.month_key,
			11 as index_id,
			coalesce(b.dnck_rate*a.phi_cctg,0)/1000000 as amount,
			b.area_code
		from
			(
			select 
			 	vmonthkey as month_key,
			    area_code,
				sum(outstanding_principal)/x.avg_dnck as dnck_rate
			from fact_kpi_month_raw_data fkmrd2 
			join 
			    (
				select 
		    		sum(outstanding_principal) as avg_dnck
		    	from fact_kpi_month_raw_data fkmrd 
		    	where
		    		kpi_month >= (vmonthkey/100) + 1 
		    		and kpi_month <= vmonthkey 
	    		) x
	    		on 
	    			fkmrd2.kpi_month >= (vmonthkey/100) + 1
	    			and fkmrd2.kpi_month <= vmonthkey 
			    group by
			    	x.avg_dnck,
			    	area_code
			   		) b
			left join 
			(
				select 
					vmonthkey as month_key,
					index_id,
					sum(amount)  as phi_cctg,
					area_code
				 from fact_txn_month_raw_data ftmrd2
				 where 
				 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
				 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
				 	and index_id = 11
				 group by
				 	index_id,
				 	area_code
			 ) a
		on 1=1
		union all
				select 
					vmonthkey as month_key,
					11 as index_id,
					sum(amount)/1000000  as phi_cctg,
					'A' as area_code
				 from fact_txn_month_raw_data ftmrd2
				 where 
				 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
				 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
				 	and index_id = 11
				 group by
				 	index_id,
				 	area_code
		--Chi phí vốn TT2
		union all
		select 
			b.month_key,
			a.index_id,
			b.dnck_rate*a.phi_cctg/1000000 as amount,
			b.area_code
		from
			(
			select 
			 	vmonthkey as month_key,
			    area_code,
				sum(outstanding_principal)/x.avg_dnck as dnck_rate
			from fact_kpi_month_raw_data fkmrd2 
			join 
			    (
				select 
		    		sum(outstanding_principal) as avg_dnck
		    	from fact_kpi_month_raw_data fkmrd 
		    	where
		    		kpi_month >= (vmonthkey/100) + 1
		    		and kpi_month <= vmonthkey 
	    		) x
	    		on 
	    			fkmrd2.kpi_month >= (vmonthkey/100) + 1
	    			and fkmrd2.kpi_month <= vmonthkey 
			    group by
			    	x.avg_dnck,
			    	area_code
			   		) b
			left join 
			(
				select 
					vmonthkey as month_key,
					index_id,
					sum(amount)  as phi_cctg,
					area_code
				 from fact_txn_month_raw_data ftmrd2
				 where 
				 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
				 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
				 	and index_id = 10
				 group by
				 	index_id,
				 	area_code
			 ) a
		on 1=1
		union all
				select 
					vmonthkey as month_key,
					index_id,
					sum(amount)/1000000  as phi_cctg,
					area_code
				 from fact_txn_month_raw_data ftmrd2
				 where 
				 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
				 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
				 	and index_id = 10
				 group by
				 	index_id,
				 	area_code;
		--Chi phí thuần KDV lấy tổng các index 9,10,11,12 đã thêm vào report_monthly ở trên
	insert into report_monthly  
		(month_key, index_id, amount, area_code)
		select 
			vmonthkey as month_key,
			8 as index_id,
			sum
				(
				case 
					when index_id in (9,10,11,12) then amount
				end
				) as amount,
			area_code
		from report_monthly 
		where month_key = vmonthkey
		group by area_code
		--CP hoa hồng
		union all
		select 
			a.month_key,
			a.index_id,
			coalesce(a.lai_trong_han + b.dnck_rate_n1*(
											select 
												sum(amount)  as lai_trong_han
											 from fact_txn_month_raw_data ftmrd2
											 where
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
											 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey 
											 	and index_id = 17 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_trong_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_trong_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
			 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 17
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	vmonthkey as month_key,
			   area_code,
				sum(outstanding_principal)/x.avg_dnck_n1 as dnck_rate_n1
			from fact_kpi_month_raw_data fkmrd2 
			join 
			    (
				select 
		    		sum(outstanding_principal) as avg_dnck_n1
		    	from fact_kpi_month_raw_data fkmrd 
		    	where 
		    		kpi_month >= (vmonthkey/100) + 1
		    		and kpi_month <= vmonthkey 
	    		) x
	    		on 
	    			fkmrd2.kpi_month >= (vmonthkey/100) + 1
	    			and fkmrd2.kpi_month <= vmonthkey
			    group by
			    	x.avg_dnck_n1,
			    	area_code
			   		) b
		on a.area_code = b.area_code
		--CP thuần KD khác
		union all
		select 
			a.month_key,
			a.index_id,
			coalesce(a.lai_trong_han + b.dnck_rate_n1*(
											select 
												sum(amount)  as lai_trong_han
											 from fact_txn_month_raw_data ftmrd2
											 where 
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
											 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey 
											 	and index_id = 18 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_trong_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_trong_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
			 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 18
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	vmonthkey as month_key,
			   area_code,
				sum(outstanding_principal)/x.avg_dnck_n1 as dnck_rate_n1
			from fact_kpi_month_raw_data fkmrd2 
			join 
			    (
				select 
		    		sum(outstanding_principal) as avg_dnck_n1
		    	from fact_kpi_month_raw_data fkmrd 
		    	where 
		    		kpi_month >= (vmonthkey/100) + 1
		    		and kpi_month <= vmonthkey 
	    		) x
	    		on 
	    			fkmrd2.kpi_month >= (vmonthkey/100) + 1
	    			and fkmrd2.kpi_month <= vmonthkey
			    group by
			    	x.avg_dnck_n1,
			    	area_code
			   		) b
		on a.area_code = b.area_code
		--DT kinh doanh
		union all
		select 
			a.month_key,
			a.index_id,
			coalesce(a.lai_trong_han + b.dnck_rate_n1*(
											select 
												sum(amount)  as lai_trong_han
											 from fact_txn_month_raw_data ftmrd2
											 where 
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
											 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey 
											 	and index_id = 16 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_trong_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_trong_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
			 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 16
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	vmonthkey as month_key,
			   area_code,
				sum(outstanding_principal)/x.avg_dnck_n1 as dnck_rate_n1
			from fact_kpi_month_raw_data fkmrd2 
			join 
			    (
				select 
		    		sum(outstanding_principal) as avg_dnck_n1
		    	from fact_kpi_month_raw_data fkmrd 
		    	where 
		    		kpi_month >= (vmonthkey/100) + 1
		    		and kpi_month <= vmonthkey 
	    		) x
	    		on 
	    			fkmrd2.kpi_month >= (vmonthkey/100) + 1
	    			and fkmrd2.kpi_month <= vmonthkey
			    group by
			    	x.avg_dnck_n1,
			    	area_code
			   		) b
		on a.area_code = b.area_code;
		--Chi phí thuần hoạt động khác
	insert into report_monthly  
		(month_key, index_id, amount, area_code)
		select 
			vmonthkey as month_key,
			13 as index_id,
			sum
				(
				case 
					when index_id in (14,15,16,17,18,19) then amount
				end
				) as amount,
			area_code
		from report_monthly 
		where month_key = vmonthkey
		group by area_code;
		--Tổng thu nhập hoạt động là tổng các index 2,8,13
	insert into report_monthly  
		(month_key, index_id, amount, area_code)
		select 
			vmonthkey as month_key,
			20 as index_id,
			sum
				(
				case 
					when index_id in (2,8,13) then amount
				end
				) as amount,
			area_code
		from report_monthly 
		where month_key = vmonthkey
		group by area_code
		-- CP thuế, phí
		union all
		select 
			a.month_key,
			22 as index_id,
			coalesce(a.lai_trong_han + b.slnv_rate*(
											select 
												sum(amount)  as lai_trong_han
											 from fact_txn_month_raw_data ftmrd2
											 where 
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
											 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey 
											 	and index_id = 22 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_trong_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_trong_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
			 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 22
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	month_key,
			 	area_code,
				count(1)::numeric/x.total_slnv as slnv_rate
			from kpi_asm_data_changed a
			join 
			    (
				select 
		    		count(1) as total_slnv 
		    	from kpi_asm_data_changed 
		    	where month_key = vmonthkey
	    		) x
	    		on month_key = vmonthkey
			    group by
			    	a.month_key,
			    	x.total_slnv,
			    	a.area_code
			   		) b
		on a.area_code = b.area_code
		--CP nhân viên
		union all
		select 
			a.month_key,
			a.index_id,
			coalesce(a.lai_trong_han + b.slnv_rate*(
											select 
												sum(amount)  as lai_trong_han
											 from fact_txn_month_raw_data ftmrd2
											 where 
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
											 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey 
											 	and index_id = 23 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_trong_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_trong_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
			 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 23
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	month_key,
			 	area_code,
				count(1)::numeric/x.total_slnv as slnv_rate
			from kpi_asm_data_changed a
			join 
			    (
				select 
		    		count(1) as total_slnv 
		    	from kpi_asm_data_changed 
		    	where month_key = vmonthkey
	    		) x
	    		on month_key = vmonthkey
			    group by
			    	a.month_key,
			    	x.total_slnv,
			    	a.area_code
			   		) b
		on a.area_code = b.area_code
		--CP quản lý
		union all
		select 
			a.month_key,
			a.index_id,
			coalesce(a.lai_trong_han + b.slnv_rate*(
											select 
												sum(amount)  as lai_trong_han
											 from fact_txn_month_raw_data ftmrd2
											 where 
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
											 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey 
											 	and index_id = 24 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_trong_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_trong_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
			 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 24
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	month_key,
			 	area_code,
				count(1)::numeric/x.total_slnv as slnv_rate
			from kpi_asm_data_changed a
			join 
			    (
				select 
		    		count(1) as total_slnv 
		    	from kpi_asm_data_changed 
		    	where month_key = vmonthkey
	    		) x
	    		on month_key = vmonthkey
			    group by
			    	a.month_key,
			    	x.total_slnv,
			    	a.area_code
			   		) b
		on a.area_code = b.area_code
		--CP Tài sản
		union all
		select 
			a.month_key,
			a.index_id,
			coalesce(a.lai_trong_han + b.slnv_rate*(
											select 
												sum(amount)  as lai_trong_han
											 from fact_txn_month_raw_data ftmrd2
											 where 
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
											 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey 
											 	and index_id = 25 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_trong_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_trong_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
			 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 25
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	month_key,
			 	area_code,
				count(1)::numeric/x.total_slnv as slnv_rate
			from kpi_asm_data_changed a
			join 
			    (
				select 
		    		count(1) as total_slnv 
		    	from kpi_asm_data_changed 
		    	where month_key = vmonthkey
	    		) x
	    		on month_key = vmonthkey
			    group by
			    	a.month_key,
			    	x.total_slnv,
			    	a.area_code
			   		) b
		on a.area_code = b.area_code;
	
		--Tổng chi phí là tổng các index 22,23,24,25
	insert into report_monthly  
		(month_key, index_id, amount, area_code)
		select 
			vmonthkey as month_key,
			21 as index_id,
			sum
				(
				case 
					when index_id in (22,23,24,25) then amount
				end
				) as amount,
			area_code
		from report_monthly 
		where month_key = vmonthkey
		group by area_code
	
		--CP dự phòng
	union all	
		select 
			a.month_key,
			a.index_id,
			coalesce(a.lai_trong_han + b.dnck_rate_n2_5*(
											select 
												sum(amount)  as lai_trong_han
											 from fact_txn_month_raw_data ftmrd2
											 where 
											 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
											 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey 
											 	and index_id = 26 and split_part(analysis_code, '.', 4) = '00'
										 	),a.lai_trong_han)/1000000 as amount,
			a.area_code 
		from 
		(
			select 
				vmonthkey as month_key,
				index_id,
				sum(amount)  as lai_trong_han,
				area_code
			 from fact_txn_month_raw_data ftmrd2
			 where 
			 	extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int >= (vmonthkey/100) + 1
			 	and extract(year from transaction_date)::int*100 + extract(month from transaction_date)::int <= vmonthkey
			 	and index_id = 26
			 group by
			 	index_id,
			 	area_code
		 ) a
		left join
			(
			select 
			 	vmonthkey as month_key,
				area_code,
				(sum(case when max_bucket >= 2 then outstanding_principal end) + coalesce(sum(case when write_off_month <= vmonthkey and write_off_month >= 202301 then write_off_balance_principal end),0))/x.avg_dnck_n2_5 as dnck_rate_n2_5
			from fact_kpi_month_raw_data fkmrd2 
			join 
			    (
				select 
		    		sum(case when max_bucket >= 2 then outstanding_principal end) + coalesce(sum(case when write_off_month <= vmonthkey and write_off_month >= 202301 then write_off_balance_principal end),0) as avg_dnck_n2_5
		    	from fact_kpi_month_raw_data fkmrd 
		    	where 
		    		kpi_month >= (vmonthkey/100) + 1
		    		and kpi_month <= vmonthkey
	    		) x
	    		on 
	    			fkmrd2.kpi_month >= (vmonthkey/100) + 1
	    			and fkmrd2.kpi_month <= vmonthkey
			    group by
			    	x.avg_dnck_n2_5,
			    	area_code
			   		) b
		on a.area_code = b.area_code;
		--Lợi nhuận trước thuế là tổng các mã 20,21,26
		insert into report_monthly  
		(month_key, index_id, amount, area_code)
		select 
			vmonthkey as month_key,
			1 as index_id,
			sum
				(
				case 
					when index_id in (20,21,26) then amount
				end
				) as amount,
			area_code
		from report_monthly 
		where month_key = vmonthkey
		group by area_code
		--Số lượng nhân sự
	union all
		select 
			month_key,
			27 as index_id,
			count(1) as amount,
			area_code
		from kpi_asm_data_changed 
		where month_key = vmonthkey 
		group by month_key,area_code
		union all
		select
			month_key,
			27 as index_id,
	    	count(1) as total_slnv,
	    	'A' as area_code
	    from kpi_asm_data_changed
	    where month_key = vmonthkey
	    group by month_key;
		--CIR là index 21 chia 20
	insert into report_monthly  
		(month_key, index_id, amount, area_code)
		select 
			vmonthkey as month_key,
			29 as index_id,
			-sum
				(
				case 
					when index_id in (21) then amount
				end
				)*100::float8/
			sum
				(
				case 
					when index_id in (20) then amount
				end
				)as amount,
			area_code
		from report_monthly 
		where month_key = vmonthkey
		group by area_code
		--Margin là index 1 chia cho tổng 2,9,14,15,16
	union all
		select 
			vmonthkey as month_key,
			30 as index_id,
			sum
				(
				case 
					when index_id in (1) then amount
				end
				)*100::float8/
			sum
				(
				case 
					when index_id in (2,9,14,15,16) then amount
				end
				)as amount,
			area_code
		from report_monthly 
		where month_key = vmonthkey
		group by area_code
		--Hiệu suất trên/vốn (%) là 1 chia cho 8
	union all
		select 
			vmonthkey as month_key,
			31 as index_id,
			-sum
				(
				case 
					when index_id in (1) then amount
				end
				)*100::float8/
			sum
				(
				case 
					when index_id in (8) then amount
				end
				)as amount,
			area_code
		from report_monthly 
		where month_key = vmonthkey
		group by area_code
		--Hiệu suất BQ/ Nhân sự là 1 chia 27
	union all
		select 
			vmonthkey as month_key,
			32 as index_id,
			sum
				(
				case 
					when index_id in (1) then amount
				end
				)::float8/
			sum
				(
				case 
					when index_id in (27) then amount
				end
				)as amount,
			area_code
		from report_monthly 
		where month_key = vmonthkey
		group by area_code;
	
   	--Bước 5: Ghi nhận thời gian kết thúc và ghi exception
	v_end_time := CURRENT_TIMESTAMP;
		--+update table with end time
	UPDATE log_tracking
    SET end_time = v_end_time,
        is_successful = v_is_successful
    WHERE log_id = v_log_id;
   	--address exception and notice that procedure isn't completed
	exception
		when others then
			v_end_time := CURRENT_TIMESTAMP;
       	 	v_is_successful := 'N';
        	v_error_log := SQLERRM;
		UPDATE log_tracking
        SET end_time = v_end_time,
            is_successful = v_is_successful,
            error_log = v_error_log
        WHERE log_id = v_log_id;
end;
$procedure$
;
--Gọi Procedure với tháng 2 giả định
call report_asm_ranking(202302);
