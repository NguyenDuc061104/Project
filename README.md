# Project: Assessing the financial growth of the business and ranking employees by region

## Table of Contents
[1. Overview of the topic](#1-Overview-of-the-topic)

[2. Data processing](#2-Data-processing)

[3. Dashboards](#3-Dashboards)

[4. View this dashboard](#4-View-this-dashboard)

[5. Conclusion](#5-Conclusion)

## 1. Overview of the topic

### Objectives
 This data analysis aims to provide detailed information to have a clear overview of the business performance in the year and its nationwide regional network and highlight key strengths in operational performance to improve efficiency across the network.

 In addition, it also helps us assess the capabilities of employees in each region through the Area Sales Manager (ASM) to promote a culture of responsibility and continuous development among ASMs. By analyzing different aspects of financial performance across all network areas and ASM KPIs, we can gain insights to maintain performance and improve the capabilities of senior managers in the company.

### Data Sources
Data is collected from various departments at the headquarters, including Sales and Operations, Accounting and ASM records.

- File `fact_txn_month_raw_data`: Records the income and expenses incurred by the financial activities of the enterprise in the General Ledger.

- File `fact_kpi_month_raw_data`: Records the final balance of card activities at the end of each month.

- File `fact_kpi_asm`: raw data on ASM monthly sales performance.

### Output
The objective is to develop a comprehensive regional business performance analysis report and a thorough employee performance evaluation report. Furthermore, a dashboard will be established to facilitate the visualization and analysis of these insights, thereby enabling more effective data-driven decision-making and strategic planning.





## 2. Data Processing
### Tool
- Data Processing: Dbeaver + Postgresql

- Data Visualization: Power BI

### Flowchart
![image](https://github.com/user-attachments/assets/f6725227-fe36-4c76-ba22-7cb9d5fa2aef)




### Data Transformation

- Project Description: [Description Projecct.xlsx](https://github.com/zerus456/Project/blob/main/Project%20Description.xlsx)


- Use Dbeaver to import into the database

 File `fact_txn_month_raw_data`

![image](https://github.com/user-attachments/assets/b4a94931-169a-4e51-a9b7-a3f92e90eafe)





 File `fact_kpi_month_raw_data`

 ![image](https://github.com/user-attachments/assets/9ab93669-f2af-424d-b692-dd1bd5c53d9a)



 File `fact_kpi_asm`

![image](https://github.com/user-attachments/assets/da8026a5-2b37-4c38-b9d8-195ba7385caf)


- Create dimension tables by using PostgreSQL Data Definition Language (DDL) [View more](https://github.com/zerus456/Project/blob/main/table.sql)

Table: `dim_asm`: Information about employees in each area
![image](https://github.com/user-attachments/assets/0798757f-66e7-443d-b2b5-cca3e204c76c)


Table `dim_city`: Information about cities in each zone area
![image](https://github.com/user-attachments/assets/5ef1b30e-aa0e-4502-bf19-3e74dd3a79b8)

Table `dim_report_item`: Information about the criteria of the report table
![image](https://github.com/user-attachments/assets/0ab08467-e6ba-40c7-a721-a5c56bcec77e)

- Use PL/SQL programming to create a report that runs for each month in 2023.

By providing the YYYYMM parameter, the system can dynamically generate monthly reports by extracting relevant data from the fact tables and joining it with the pre-defined dimension tables. This automated process ensures consistency, reduces manual intervention, and allows for scalable reporting across different time periods with accurate and up-to-date information. [View more](https://github.com/zerus456/Project/blob/main/procedure_report.sql)

## 3. Dashboards

- I used PowerBI to connect to the postgresql database on dbeaver using the psycopg2 library. I then used to visualize the data for the report to give users a more general view.

- Based on the two output tables generated from the data processing and aggregation steps, I developed and visualized six distinct dashboard pages. Each page is equipped with detailed charts, key performance indicators, and in-depth analyses, providing the business with a comprehensive view of financial performance and employee capabilities across regions. These reports serve as powerful decision-support tools, enabling the leadership team to monitor business performance, identify issues, and propose effective strategies to enhance operational efficiency in the financial sector. 

**`Business requirements`**:  *Presents the goals, input data sources, report outputs, and data processing procedures illustrated with visual diagrams to help viewers understand the overall system.*
![image](https://github.com/user-attachments/assets/fb3fd7d9-2a12-467d-bab3-cd181f42d3d0)




**`Regional summary report page`**: *Highlights key financial metrics and performance overview*

![image](https://github.com/user-attachments/assets/7a2b08e4-9684-4e0b-a448-809c40fbf466)




**`Regional employee ranking report page`**: provides a detailed report of Regional Sales Manager rankings across all criteria and highlights the increase or decrease in rankings for each ASM*

![image](https://github.com/user-attachments/assets/fdf9ef5d-0fac-4002-9b4d-3b31f39c21af)



**`Overview report page`**: The consolidated revenue report page provides an overview of profit, revenue, expenses, and business performance by region with detailed charts and comments.

![image](https://github.com/user-attachments/assets/c212b20b-a46b-4cd2-b103-efbb5267cb10)



**`Cumulative Expenses Page`**: The all-in-one cost tracking report page shows trends, distributions, and cost weights by region to help evaluate cost management effectiveness.

![image](https://github.com/user-attachments/assets/674e9fc6-a1c4-4dc8-815f-7bade19122d6)



**`ASM Evaluation`**: The ASM evaluation report page summarizes personnel rankings, regional distribution, and outstanding individual business performance.

![image](https://github.com/user-attachments/assets/51a50288-3900-4580-8167-89cd53865361)



## 4. view this dashboard 

Check my dashboard here: [View my dashboard](https://app.powerbi.com/view?r=eyJrIjoiMDljNmJkMzEtZjk4NS00ZDljLThjM2EtNTEyNWEzOTllMzI2IiwidCI6IjZhYzJhZDA2LTY5MmMtNDY2My1iN2FmLWE5ZmYyYTg2NmQwYyIsImMiOjEwfQ%3D%3D)




## 5. Conclusion


Through this personal project, I not only improved my SQL skills, but also learned how to organize data, store it efficiently, and retrieve it when needed. In addition, I gained experience in data visualization by connecting to a database and using PowerBI. Most importantly, I developed a clearer understanding of how data analysis can benefit a business. This allowed me to present data in a way that delivers the most valuable insights to viewers, especially the management team.

Since this is my first project, there are certainly unavoidable mistakes. If you have any feedback, please reach out at anduc061104@gmail.com.

**I believe this project showcases my end-to-end understanding of the data analysis pipeline—from data ingestion to dashboard delivery—and my ability to turn data into meaningful business insights.**



























💻📖😄
