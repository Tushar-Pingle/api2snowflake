{{
    config(
        materialized='view',
        tags=['intermediate', 'daily', 'returns'],
        meta={
            'owner': 'data_engineering',
            'Contains_PII': false
        }
    )
}}

{#
Model: int_stock_returns
Purpose: Calculate daily returns, intraday volatility and trading metrics

Business Logic:
- Daily return: percentage change from previous day's close
- Intraday volatility: price range % as of opening day price
- Volume adjusted metrics: Price movements normalized by trading volume

Grain: One row per ticker per trading day

Notes:
- Returns are null for first trading day
- Zero or negative values are handled to prevent division errors
- Volume normalization uses per million shares for readability

Last Updated: 2025-11-08
Author: T
#}

with daily_prices as (
    -- Source: Staging layer with cleaned Polygon.io data
    select * from {{ ref('stg_stock_prices') }}
),

calculate_metrics as (
    select
        -- Dimensions: Stock identifier and dates
        ticker,
        company_name,
        trade_date,
        timestamp,

        -- Price facts: OHLC data from source
        open_price,
        high_price,
        low_price,
        close_price,

        -- Volume Facts: Trading activity
        volume,
        vwap,
        num_transactions,

        -- Calculated metric: Daily return %
        -- Formula: ((today close - yesterday close) / yesterday close) * 100
        -- Null Handling: Returns null if no prior price exists
        -- Use Case: Measures day over day price momentum
        case
            when lag(close_price) over (partition by ticker order by trade_date) > 0
            then (
                (close_price - lag(close_price) over (partition by ticker order by trade_date))
                / lag(close_price) over (partition by ticker order by trade_date)
            ) * 100
            else null
        end as daily_return_pct,

        -- Calculated Metrics: Intraday price range
        -- Formula: High - low
        -- Use case: Raw dollar volatility within trading day
        high_price - low_price as intraday_range,

        -- Calculated Metric: Intraday Volatility %
        -- Formula: ((High - Low) / Open) * 100
        -- Use case: Identifies highly volatile trading days
        case 
            when open_price > 0 
            then ((high_price - low_price) / open_price) * 100
            else null
        end as intraday_volatility_pct,

        -- Calculated Metric: Price Change per volume
        -- Formula: ((close-open)/volume) * 1,000,000
        -- Interpretation: Price movement per million shares traded
        -- Use case: Detects price manipulation or unusual trading patterns
        -- Note: Multiplied by 1M for human readable scale
        case
            when volume > 0
            then (close_price - open_price) / volume * 1000000
            else null
        end as price_change_per_volume

    from daily_prices  
)

select * 
from calculate_metrics
-- Filter out any records with missing dates
where trade_date is not null
order by ticker, trade_date