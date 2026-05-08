CREATE VIEW vw_Cleaned_Retail_Sales AS
--Create Reference Mapping to gather reference list category and fill details in Sales data
WITH Product_Dim AS ( 
    SELECT [Item_Code], [Price], 'Electric household essentials' AS Category FROM [Electric Household Essentials] 
    UNION ALL 
    SELECT [Item_Code], [Price], 'Furniture' AS Category FROM [Furniture] 
), 
/*
Used a JOIN to fill in the blanks. 

If an item was missing its ID but had a price and category, I mapped it back to the 
correct product. 

I used a 'REC_' prefix for any category I didn't have 
specific IDs for yet to keep my revenue totals 100% accurate.

If quantity was missing, I used (Total Spent / Price) 
to find the missing number, defaulting to 1 where no other math was possible.
*/
Data_Normalization  AS ( 
    SELECT rs.* 
    ,COALESCE(rs.[Item], pd.[Item_Code], 'REC_' + rs.[Category]) AS [Item_Normalized] 
    ,COALESCE(rs.Price_Per_Unit, pd.Price) AS [Price_Normalized] 
    ,COALESCE(rs.Quantity, (rs.Total_Spent / NULLIF(pd.Price, 0)), 1) AS [Quantity_Normalized] 
    ,COALESCE(Discount_Applied, 'False') AS [Is_Discounted] 
    ,DATENAME(DW, [Transaction_Date]) AS [Day_of_Week]
    FROM retail_store_sales rs 
    LEFT JOIN Product_Dim pd 
    ON CAST(rs.Price_Per_Unit AS DECIMAL(10,2)) = CAST(pd.Price AS DECIMAL(10,2)) 
    AND rs.Category = pd.Category
),
/*
If total is missing, I used (normalized quantity * normalized Price) to find the missing number
*/
Fixed_Total AS (
    SELECT * 
    ,CAST(COALESCE(Total_Spent, ([Price_Normalized] * [Quantity_Normalized])) AS DECIMAL(10,2)) AS [Final_Total_Spent]
    FROM Data_Normalization 
)
 --Final Output
SELECT 
     [Transaction_ID] 
    ,[Customer_ID] 
    ,[Category] 
    ,[Item_Normalized] as [Item]
    ,[Price_Normalized] as [Price]
    ,[Quantity_Normalized] as [Quantity]
    ,[Final_Total_Spent] 
    ,[Is_Discounted] 
    ,[Payment_Method] 
    ,[Location] 
    ,[Transaction_Date] 
    ,[Day_of_Week] 
    ,SUM([Final_Total_Spent]) OVER(PARTITION BY Customer_ID) AS [Customer_LTV] 
FROM Fixed_Total

