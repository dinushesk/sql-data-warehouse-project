
/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This creates views for the Gold layer in the data warehouse.

    It performs the following actions:
    - Creates or alters the Customer Dimension View.
    - Creates or alters the Product Dimension View.
    - Creates or alters the Sales Fact View.
    - Tracks individual view creation durations.
    - Tracks total Gold Layer execution duration.

Parameters:
    None.

Usage Example:
    EXEC gold.load_gold;
    It can be used to query directly for analytics and reporting

Note:
    Gold objects are views, not physical tables.
    Therefore, TRUNCATE and INSERT are not required.
===============================================================================
*/

        
/*
===============================================================================
Stored Procedure: Load Gold Layer (Silver -> Gold)
===============================================================================
Script Purpose:
    This stored procedure creates the Gold Layer views.

    It performs the following actions:
    - Drops existing Gold views if they exist.
    - Creates Customer Dimension View.
    - Creates Product Dimension View.
    - Creates Sales Fact View.
    - Tracks individual view creation durations.
    - Tracks total Gold Layer execution duration.

Usage Example:
    EXEC gold.load_gold;
===============================================================================
*/

CREATE OR ALTER PROCEDURE gold.load_gold AS
BEGIN

    DECLARE
        @start_time DATETIME,
        @end_time DATETIME,
        @batch_start_time DATETIME,
        @batch_end_time DATETIME;

    BEGIN TRY

        SET @batch_start_time = GETDATE();

        PRINT '================================================';
        PRINT 'Loading Gold Layer';
        PRINT '================================================';


        -- =============================================
        -- 1. Customer Dimension
        -- =============================================

        SET @start_time = GETDATE();

        PRINT '>> Checking if View Exists: gold.dim_customers';

        IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
            DROP VIEW gold.dim_customers;

        PRINT '>> Creating View: gold.dim_customers';

        EXEC sp_executesql N'
        CREATE VIEW gold.dim_customers AS

        SELECT
            ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,
            ci.cst_id AS customer_id,
            ci.cst_key AS customer_number,
            ci.cst_firstname AS first_name,
            ci.cst_lastname AS last_name,
            la.cntry AS country,
            ci.cst_marital_status AS marital_status,
            CASE
                WHEN ci.cst_gndr != ''n/a'' THEN ci.cst_gndr
                ELSE COALESCE(ca.gen, ''n/a'')
            END AS gender,
            ca.bdate AS birthdate,
            ci.cst_create_date AS create_date
        FROM silver.crm_cust_info ci
        LEFT JOIN silver.erp_cust_az12 ca
            ON ci.cst_key = ca.cid
        LEFT JOIN silver.erp_loc_a101 la
            ON ci.cst_key = la.cid;
        ';

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '>> -------------';


        -- =============================================
        -- 2. Product Dimension
        -- =============================================

        SET @start_time = GETDATE();

        PRINT '>> Checking if View Exists: gold.dim_produts';

        IF OBJECT_ID('gold.dim_produts', 'V') IS NOT NULL
            DROP VIEW gold.dim_produts;

        PRINT '>> Creating View: gold.dim_produts';

        EXEC sp_executesql N'
        CREATE VIEW gold.dim_produts AS

        SELECT
            ROW_NUMBER() OVER (
                ORDER BY pn.prd_start_dt, pn.prd_key
            ) AS product_key,
            pn.prd_id AS product_id,
            pn.prd_key AS product_number,
            pn.prd_nm AS product_name,
            pn.cat_id AS category_id,
            pc.cat AS category,
            pc.subcat AS subcategory,
            pc.maintenance,
            pn.prd_cost AS cost,
            pn.prd_line AS product_line,
            pn.prd_start_dt AS start_date
        FROM silver.crm_prd_info pn
        LEFT JOIN silver.erp_px_cat_g1v2 pc
            ON pn.cat_id = pc.id
        WHERE pn.prd_end_dt IS NULL;
        ';

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '>> -------------';


        -- =============================================
        -- 3. Sales Fact
        -- =============================================

        SET @start_time = GETDATE();

        PRINT '>> Checking if View Exists: gold.fact_sales';

        IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
            DROP VIEW gold.fact_sales;

        PRINT '>> Creating View: gold.fact_sales';

        EXEC sp_executesql N'
        CREATE VIEW gold.fact_sales AS

        SELECT
            sd.sls_ord_num AS order_number,
            pr.product_key,
            cu.customer_key,
            sd.sls_order_dt AS order_date,
            sd.sls_ship_dt AS shipping_date,
            sd.sls_due_dt AS due_date,
            sd.sls_sales AS sales_amount,
            sd.sls_quantity AS quantity,
            sd.sls_price AS price
        FROM silver.crm_sales_details sd
        LEFT JOIN gold.dim_produts pr
            ON sd.sls_prd_key = pr.product_number
        LEFT JOIN gold.dim_customers cu
            ON sd.sls_cust_id = cu.customer_id;
        ';

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '>> -------------';


        -- =============================================
        -- BATCH COMPLETION
        -- =============================================

        SET @batch_end_time = GETDATE();

        PRINT '================================================';
        PRINT 'Loading Gold Layer is Completed';
        PRINT '   - Total Load Duration: '
            + CAST(
                DATEDIFF(SECOND, @batch_start_time, @batch_end_time)
                AS NVARCHAR
            )
            + ' seconds';
        PRINT '================================================';

    END TRY

    BEGIN CATCH

        PRINT '================================================';
        PRINT 'ERROR OCCURRED DURING LOADING GOLD LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '================================================';

        THROW;

    END CATCH

END;

