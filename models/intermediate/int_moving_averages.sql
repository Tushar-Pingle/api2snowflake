{{
    config(
        materialized='view',
        tags=['intermediate', 'technical_analysis', 'time_series'],
        meta={
            'owner': 'analytics_engineering',
            'Contains_PII': false,
            'refresh_frequency': 'daily'
        }
    )
}}

{# ============================================================================
   MODEL: int_moving_averages
   PURPOSE: Calculate technical indicators for stock price trend analysis
   
   BUSINESS LOGIC:
   - Simple Moving Averages (SMA): Trend identification
   - Volume Averages: Liquidity analysis
   - Rolling Volatility: Risk assessment
   
   TECHNICAL INDICATORS:
   - SMA 7-day: Short-term trend (1 week trading days)
   - SMA 30-day: Medium-term trend (~1 month trading days)
   - SMA 90-day: Long-term trend (~1 quarter trading days)
   
   DEPENDENCIES:
   - int_stock_returns: Stock returns and volatility metrics
   
   GRAIN: One row per ticker per trading day
   
   NOTES:
   - Moving averages use ROWS BETWEEN (not RANGE) for exact day counts
   - First N days will have partial averages (e.g., day 3 has 3-day avg)
   - Volatility calculated as standard deviation of daily returns
   
   TRADING STRATEGIES ENABLED:
   - Golden Cross: When SMA 7 crosses above SMA 30 (bullish signal)
   - Death Cross: When SMA 7 crosses below SMA 30 (bearish signal)
   - Bollinger Bands: Can be derived from SMA + volatility
   
   LAST UPDATED: 2025-11-08
   AUTHOR: T
============================================================================ #}

with stock_returns as (
    -- Source: Intermediate layer with calculated returns
    select * from {{ ref('int_stock_returns') }}
),

add_moving_averages as (
    select
        -- DIMENSIONS: Stock identifiers
        ticker,
        company_name,
        trade_date,

        -- BASE METRICS: Core price and volume
        close_price,
        volume,
        daily_return_pct,

        -- TECHNICAL INDICATOR: 7-Day SMA
        -- Window: Current day + 6 prior days = 7 trading days
        -- Use case: Identifies short-term price trends
        -- Trading signal: Price crossing above/below indicates momentum shift
        avg(close_price) over (
            partition by ticker
            order by trade_date
            rows between 6 preceding and current row
        ) as sma_7_day,

        -- TECHNICAL INDICATOR: 30-Day SMA
        -- Window: Current day + 29 prior days = ~1 month trading days
        -- Use case: Medium-term trend identification
        -- Trading signal: Golden/Death cross when compared to short-term SMA
        avg(close_price) over (
            partition by ticker
            order by trade_date
            rows between 29 preceding and current row
        ) as sma_30_day,

        -- TECHNICAL INDICATOR: 90-Day SMA
        -- Window: Current day + 89 prior days = ~1 quarter trading days
        -- Use case: Long-term trend and support/resistance levels
        -- Note: Strong indicator of secular trends (bull vs bear market)
        avg(close_price) over (
            partition by ticker
            order by trade_date
            rows between 89 preceding and current row
        ) as sma_90_day,

        -- LIQUIDITY METRIC: 7-Day Average Volume
        -- Window: Rolling 7-day average of shares traded
        -- Use case: Identifies unusual trading activity
        -- Alert trigger: Current volume > 2x avg_volume = high liquidity event
        avg(volume) over (
            partition by ticker
            order by trade_date
            rows between 6 preceding and current row
        ) as avg_volume_7_day,

        -- RISK METRIC: 30-Day Volatility
        -- Formula: Standard deviation of daily returns over 30 days
        -- Interpretation: Higher values = higher price unpredictability
        -- Use case: Risk-adjusted portfolio construction
        -- Benchmark: Annual volatility = 30-day volatility * sqrt(252 trading days)
        stddev(daily_return_pct) over (
            partition by ticker
            order by trade_date
            rows between 29 preceding and current row
        ) as volatility_30_day

    from stock_returns
)

select *
from add_moving_averages
-- Maintain chronological order for time-series analysis
order by ticker, trade_date