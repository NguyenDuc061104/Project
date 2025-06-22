CREATE TABLE du_no_sau_wo (
    area VARCHAR(50),          -
    kpi_month INT,          
    du_no_ck DECIMAL(18, 2),  
    du_no_nhom_1 DECIMAL(18, 2),
    du_no_nhom_2 DECIMAL(18, 2), 
    du_no_nhom_345 DECIMAL(18, 2) 
); 
CREATE TABLE tmp_head (
    id int PRIMARY KEY,       -- 
    amount DECIMAL(18, 2) NOT NULL
);
CREATE TABLE baocao_tonghop (
	id int,
    information VARCHAR(255),  -- Kiểu dữ liệu có thể cần điều chỉnh
    Head NUMERIC,              -- Giả định kiểu dữ liệu là số
    dong_bac_bo NUMERIC,
    tay_bac_bo NUMERIC,
    db_song_hong NUMERIC,
    bac_trung_bo NUMERIC,
    nam_trung_bo NUMERIC,
    tay_nam_bo NUMERIC,
    dong_nam_bo NUMERIC
);
CREATE TABLE fact_ranking_asm  (
    month_key INT,
    area_code VARCHAR(1024),
    area_name VARCHAR(1024),
    email VARCHAR(1024),
    tong_diem INT,
    rank_final INT,
    ltn_avg FLOAT8,
    rank_ltn_avg INT,
    psdn_avg NUMERIC,
    rank_psdn_avg NUMERIC,
    approval_rate_avg NUMERIC,
    rank_approval_rate_avg INT,
    npl_truoc_wo_luy_ke NUMERIC,
    rank_npl_truoc_wo_luy_ke INT,
    diem_quy_mo INT,
    rank_ptkd INT,
    cir NUMERIC,
    rank_cir INT,
    margin NUMERIC,
    rank_margin INT,
    hs_von NUMERIC,
    rank_hs_von INT,
    hsbq_nhan_su FLOAT8,
    rank_hsbq_nhan_su INT,
    diem_fin INT,
    rank_fin INT
);
CREATE TABLE tmp_area(
	month int,
    id int not null ,         
    area_name VARCHAR(255) NOT NULL,
    amount NUMERIC(22, 4) NOT NULL)
CREATE TABLE dim_province AS  
	SELECT a.pos_cde, a.pos_city, c.area_code, c.area_name  
	FROM fact_kpi_month_data a  
	JOIN dim_city b ON a.pos_city = b.province  
	JOIN dim_area_code c ON b.province_code = c.area_code
create table dim_asm as
	select area_name,sale_name,email
	from fact_kpi_data_final fkdf 
	group by email,area_name,sale_name 
CREATE TABLE tmp_report (
    month_key INT4,
    id INT4,
    information VARCHAR(255),
    head NUMERIC,
    dong_bac_bo NUMERIC,
    tay_bac_bo NUMERIC,
    db_song_hong NUMERIC,
    bac_trung_bo NUMERIC,
    nam_trung_bo NUMERIC,
    tay_nam_bo NUMERIC,
    dong_nam_bo NUMERIC
);
create table dim_report_item(
	id int4,
	information varchar(1024),
	id_level int4
)

drop table dim_report_item 
select * from dim_report_item dri 
create table dim_ranking_asm
(
)
