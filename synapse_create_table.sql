Create schema bookymyshow;

CREATE TABLE bookymyshow.bookings_fact (
    order_id NVARCHAR(50) NOT NULL,
    booking_time DATETIME2,
    customer_id NVARCHAR(50),
    customer_name NVARCHAR(100),
    customer_email NVARCHAR(100),
    event_id NVARCHAR(50),
    event_name NVARCHAR(100),
    event_location NVARCHAR(200),
    seat_number NVARCHAR(10),
    seat_price FLOAT,
    event_category NVARCHAR(50),
    booking_day_of_week NVARCHAR(20),
    booking_hour INT,
    payment_id NVARCHAR(50),
    payment_time DATETIME2,
    amount FLOAT,
    payment_method NVARCHAR(50),
    payment_type NVARCHAR(50),
    booking_event_time DATETIME2,
    payment_event_time DATETIME2
);

select * from bookymyshow.bookings_fact;




-- ================================================
-- BOOKYMYSHOW DATABASE - Grant Managed Identity Access
-- ================================================

-- Verify you're in the correct database
SELECT DB_NAME() AS CurrentDatabase;
-- Should show: bookymyshow

-- Create user from Stream Analytics managed identity
CREATE USER [bookingmyshow_stream_analytics] FROM EXTERNAL PROVIDER;

-- Grant db_owner permissions
EXEC sp_addrolemember N'db_owner', N'bookingmyshow_stream_analytics';

-- Verify user was created
SELECT 
    name AS UserName,
    type_desc AS UserType,
    authentication_type_desc AS AuthType
FROM sys.database_principals 
WHERE name = 'bookingmyshow_stream_analytics';

-- Verify role membership
SELECT 
    dp.name AS UserName,
    r.name AS RoleName
FROM sys.database_principals dp
INNER JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
INNER JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
WHERE dp.name = 'bookingmyshow_stream_analytics';clear
