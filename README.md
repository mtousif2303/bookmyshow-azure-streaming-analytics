# bookmyshow-azure-streaming-analytics
Tech Stack : Python, EventHub, Azure Stream Analytics Job, SQL, Synapse DWH

1) Publish mock data in Booking and Payments event hub

2) Real time data transformation and window based join operations in Stream Analytics Job

3) Write query to implement things mentioned in point 2 and write final data in Synapse Table


## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          DATA GENERATION LAYER                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌──────────────────────┐              ┌──────────────────────┐            │
│  │  mock_bookings.py    │              │  mock_payments.py    │            │
│  │                      │              │                      │            │
│  │  • Generates booking │              │  • Generates payment │            │
│  │    events (JSON)     │              │    events (JSON)     │            │
│  │  • Customer details  │              │  • Payment method    │            │
│  │  • Event info        │              │  • Transaction status│            │
│  │  • Seat allocation   │              │  • Amount details    │            │
│  └──────────┬───────────┘              └──────────┬───────────┘            │
│             │                                     │                         │
└─────────────┼─────────────────────────────────────┼─────────────────────────┘
              │                                     │
              │ Publishes every 5 sec              │ Publishes every 5 sec
              ▼                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          INGESTION LAYER (Azure Event Hubs)                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌──────────────────────┐              ┌──────────────────────┐            │
│  │  bookingtopic        │              │  paymentstopic       │            │
│  │  Event Hub           │              │  Event Hub           │            │
│  │                      │              │                      │            │
│  │  • Partitioned by    │              │  • Partitioned by    │            │
│  │    order_id          │              │    order_id          │            │
│  │  • High throughput   │              │  • High throughput   │            │
│  │  • Event buffering   │              │  • Event buffering   │            │
│  └──────────┬───────────┘              └──────────┬───────────┘            │
│             │                                     │                         │
│             └─────────────────┬───────────────────┘                         │
│                               │                                             │
└───────────────────────────────┼─────────────────────────────────────────────┘
                                │
                                │ Real-time Stream Input
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PROCESSING LAYER (Stream Analytics Job)                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  TRANSFORMATION LOGIC                                                │   │
│  │                                                                       │   │
│  │  ┌────────────────────────────────────────────────────────────┐    │   │
│  │  │ 1. TransformedBookingStream (CTE)                          │    │   │
│  │  │    • Flatten nested JSON (customer, event_details)         │    │   │
│  │  │    • Explode seat arrays (CROSS APPLY)                     │    │   │
│  │  │    • Derive event_category from event_name                 │    │   │
│  │  │    • Extract temporal features:                            │    │   │
│  │  │      - booking_day_of_week (Monday, Tuesday, etc.)        │    │   │
│  │  │      - booking_hour (0-23)                                 │    │   │
│  │  │    • Cast timestamps to datetime                           │    │   │
│  │  └────────────────────────────────────────────────────────────┘    │   │
│  │                                                                       │   │
│  │  ┌────────────────────────────────────────────────────────────┐    │   │
│  │  │ 2. TransformedPaymentStream (CTE)                          │    │   │
│  │  │    • Cast payment_time to datetime                         │    │   │
│  │  │    • Categorize payment_method into payment_type           │    │   │
│  │  │      - Card (Credit/Debit)                                │    │   │
│  │  │      - Online (PayPal)                                     │    │   │
│  │  │      - Cash (other methods)                               │    │   │
│  │  └────────────────────────────────────────────────────────────┘    │   │
│  │                                                                       │   │
│  │  ┌────────────────────────────────────────────────────────────┐    │   │
│  │  │ 3. Windowed Join (Temporal)                                │    │   │
│  │  │    • JOIN ON order_id                                      │    │   │
│  │  │    • Time Window: DATEDIFF(minute, b, p) BETWEEN 0 AND 2  │    │   │
│  │  │    • Ensures payment within 2 minutes of booking          │    │   │
│  │  │    • Combines 20 fields from both streams                 │    │   │
│  │  └────────────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
└───────────────────────────────┬───────────────────────────────────────────────┘
                                │
                                │ Output Stream
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STORAGE LAYER (Azure Synapse Analytics)                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  bookymyshow.bookings_fact                                          │   │
│  │                                                                       │   │
│  │  Schema:                                                             │   │
│  │  • Business Keys: order_id, customer_id, event_id, payment_id      │   │
│  │  • Customer Dimension: name, email                                  │   │
│  │  • Event Dimension: name, location, category                        │   │
│  │  • Seat Details: seat_number, seat_price                           │   │
│  │  • Payment Facts: amount, method, type                             │   │
│  │  • Temporal Attributes: booking_time, payment_time, day, hour      │   │
│  │  • Audit Fields: booking_event_time, payment_event_time            │   │
│  │                                                                       │   │
│  │  Total Columns: 20                                                   │   │
│  │  Storage: Distributed for analytical queries                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
│  Authentication: Managed Identity (bookingmyshow_stream_analytics)          │
│  Permissions: db_owner role for write access                                │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                │
                                │
                                ▼
                        Analytics & Reporting
                    (Power BI, SQL Analytics, etc.)
```

a) EventHub topics

<img width="2970" height="1762" alt="image" src="https://github.com/user-attachments/assets/e9702587-a2ae-42c3-96ee-0ff31cfa6f14" />


b) The Azure stream analytics job 
bookingmyshow_stream_analytics

<img width="3456" height="2010" alt="image" src="https://github.com/user-attachments/assets/39ca91fb-d892-47aa-bddf-1ef09e060fa5" />


c) The Azure Synapse analytics 
The fact table for analytics

<img width="2994" height="1730" alt="image" src="https://github.com/user-attachments/assets/da071f53-017b-4058-b46d-f0161f83fc21" />


d) The Python Script to Mock the data

<img width="3454" height="2048" alt="image" src="https://github.com/user-attachments/assets/11087992-a984-4beb-9824-6f714f8a71a6" />




### BookMyShow Azure Streaming Analytics Pipeline

A real-time event booking and payment processing system built on Azure cloud services, demonstrating end-to-end streaming data pipeline with event-driven architecture.



## 🎯 Overview

This project simulates a real-time ticket booking system similar to BookMyShow, processing booking and payment events through Azure Event Hubs, performing real-time transformations and windowed joins using Azure Stream Analytics, and storing the enriched data in Azure Synapse Analytics for further analysis.

The system handles two primary event streams:
- **Booking Events**: Customer ticket bookings with event and seat details
- **Payment Events**: Payment transactions linked to bookings


## 🛠️ Tech Stack

### Core Technologies
- **Python 3.x**: Event generation and simulation
- **Azure Event Hubs**: Real-time event ingestion
- **Azure Stream Analytics**: Real-time stream processing
- **Azure Synapse Analytics**: Data warehousing
- **SQL**: Query language for transformations and data definition

### Python Libraries
- `azure-eventhub`: Event Hub client
- `faker`: Generate realistic mock data
- `json`: JSON serialization
- `random`: Random data generation

## ✨ Features

### Real-time Event Processing
- Continuous generation of booking and payment events
- Partitioned event streaming for scalability
- Low-latency event ingestion (5-second intervals)

### Advanced Stream Transformations
- **JSON Flattening**: Extract nested customer and event details
- **Array Explosion**: Transform seat arrays into individual records
- **Feature Engineering**:
  - Event categorization (Music, Theater, Cinema)
  - Temporal feature extraction (day of week, hour)
  - Payment type classification
- **Data Type Casting**: Convert string timestamps to datetime objects

### Temporal Join Operations
- Time-based windowed joins (2-minute window)
- Correlation of booking and payment events by order_id
- Event time tracking for audit purposes

### Data Warehouse Integration
- Structured fact table in Synapse Analytics
- Optimized for analytical queries
- Managed identity authentication
- Support for downstream analytics and reporting

## 📁 Project Structure

```
bookmyshow-azure-streaming-analytics/
│
├── mock_bookings.py                    # Booking event generator
├── mock_payments.py                    # Payment event generator
├── stream_analytics_job_query.sql      # Stream Analytics transformation query
├── synapse_create_table.sql            # Synapse table DDL and permissions
└── README.md                           # Project documentation
```

## 🚀 Setup Instructions

### Prerequisites
1. Azure subscription with active account
2. Python 3.8 or higher installed
3. Azure CLI installed (optional, for automation)

### Step 1: Azure Event Hubs Setup

1. Create an Event Hubs namespace in Azure Portal
2. Create two Event Hubs:
   - `bookingtopic`
   - `paymentstopic`
3. Configure partitions (recommended: 4 partitions for scalability)
4. Copy the connection string from "Shared access policies"

### Step 2: Configure Python Scripts

Update connection strings in both Python files:

```python
# mock_bookings.py and mock_payments.py
event_hub_connection_str = 'Endpoint=sb://<namespace>.servicebus.windows.net/;SharedAccessKeyName=...'
```

Install required dependencies:
```bash
pip install azure-eventhub faker
```

### Step 3: Azure Stream Analytics Job Setup

1. Create a Stream Analytics job in Azure Portal
2. Configure inputs:
   - **Input alias**: `bookings`
   - **Source**: Event Hub `bookingtopic`
   - **Serialization**: JSON
   
   - **Input alias**: `payments`
   - **Source**: Event Hub `paymentstopic`
   - **Serialization**: JSON

3. Configure output:
   - **Output alias**: `bookings-synapse`
   - **Sink**: Azure Synapse Analytics
   - **Database**: Your Synapse database
   - **Table**: `bookymyshow.bookings_fact`
   - **Authentication**: Managed Identity

4. Copy the content from `stream_analytics_job_query.sql` into the query editor

### Step 4: Azure Synapse Analytics Setup

1. Create a Synapse workspace
2. Create a dedicated SQL pool
3. Run the SQL script from `synapse_create_table.sql`:
   - Creates schema `bookymyshow`
   - Creates fact table `bookings_fact`
   - Grants permissions to Stream Analytics managed identity

4. Enable Managed Identity for Stream Analytics job:
   ```sql
   CREATE USER [bookingmyshow_stream_analytics] FROM EXTERNAL PROVIDER;
   EXEC sp_addrolemember N'db_owner', N'bookingmyshow_stream_analytics';
   ```

### Step 5: Start the Pipeline

1. Start the Stream Analytics job
2. Run the Python event generators:
   ```bash
   # Terminal 1
   python mock_bookings.py
   
   # Terminal 2
   python mock_payments.py
   ```

3. Monitor the pipeline:
   - Check Event Hub metrics for incoming events
   - Monitor Stream Analytics job metrics
   - Query Synapse table to verify data flow

## 🔄 Data Flow

### Booking Event Schema
```json
{
  "order_id": "order_2000",
  "booking_time": "2026-02-08T10:30:00Z",
  "customer": {
    "customer_id": "cust2000",
    "name": "John Doe",
    "email": "john.doe@email.com"
  },
  "event_details": {
    "event_id": "event42",
    "event_name": "Concert",
    "event_location": "123 Main St, City",
    "seats": [
      {"seat_number": "A5", "price": 75},
      {"seat_number": "A6", "price": 75}
    ]
  }
}
```

### Payment Event Schema
```json
{
  "payment_id": "payment_3000",
  "order_id": "order_2000",
  "payment_time": "2026-02-08T10:31:00Z",
  "amount": 150,
  "payment_method": "Credit Card",
  "payment_status": "Success"
}
```

### Output Schema (Synapse)
The joined and transformed data contains 20 columns combining booking and payment information with derived features for analytics.

## 📊 Stream Analytics Transformations

### Key Transformations

1. **Nested JSON Flattening**
   - Extracts `customer.customer_id`, `customer.name`, `customer.email`
   - Extracts `event_details.event_id`, `event_details.event_name`, etc.

2. **Array Processing**
   - Uses `CROSS APPLY GetArrayElements()` to explode seat arrays
   - Creates one row per seat in the booking

3. **Derived Columns**
   - `event_category`: Categorizes events as Music, Theater, or Cinema
   - `payment_type`: Groups payment methods into Card, Online, or Cash
   - `booking_day_of_week`: Extracts weekday name
   - `booking_hour`: Extracts hour (0-23) for time-based analysis

4. **Temporal Join**
   - Joins bookings and payments on `order_id`
   - Applies 2-minute time window: `DATEDIFF(minute, b, p) BETWEEN 0 AND 2`
   - Ensures payment occurs within 2 minutes of booking

## 💻 Usage

### Verify Data Pipeline

Query Synapse to check incoming data:
```sql
-- Check recent bookings
SELECT TOP 100 *
FROM bookymyshow.bookings_fact
ORDER BY booking_time DESC;

-- Analyze bookings by event category
SELECT 
    event_category,
    COUNT(*) as total_bookings,
    SUM(seat_price) as total_revenue
FROM bookymyshow.bookings_fact
GROUP BY event_category;

-- Payment method analysis
SELECT 
    payment_type,
    payment_method,
    COUNT(*) as transaction_count,
    AVG(amount) as avg_amount
FROM bookymyshow.bookings_fact
GROUP BY payment_type, payment_method;

-- Peak booking hours
SELECT 
    booking_hour,
    COUNT(*) as booking_count
FROM bookymyshow.bookings_fact
GROUP BY booking_hour
ORDER BY booking_hour;
```

### Stop the Pipeline

1. Stop Python scripts (Ctrl+C in both terminals)
2. Stop Stream Analytics job to avoid charges
3. Optionally pause Synapse SQL pool

## 🔮 Future Enhancements

- **Error Handling**: Add dead-letter queues for failed events
- **Schema Evolution**: Implement schema registry for version management
- **Data Quality**: Add validation rules and data quality checks
- **Monitoring**: Implement Azure Monitor alerts and dashboards
- **Partitioning**: Optimize Synapse table partitioning strategy
- **Real-time Dashboards**: Build Power BI reports for live analytics
- **Machine Learning**: Add fraud detection for payment events
- **Scalability**: Implement auto-scaling for Event Hubs
- **Data Retention**: Configure time-to-live policies
- **Multi-region**: Deploy across multiple Azure regions for HA

## 📝 Notes

- Events are generated every 5 seconds from each script
- Order IDs are synchronized between bookings and payments
- Payment events are generated with slight delay to simulate real transactions
- The 2-minute join window allows for payment processing time
- Managed Identity eliminates need for SQL credentials in Stream Analytics


