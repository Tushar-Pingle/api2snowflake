{{
    config(
        materialized='table',
        tags=['marts', 'fact_table', 'daily'],
        meta={
            'owner': 'analytics',
            'Contains_PII': false
        }
    )
}}

{#
Model: fct_daily_stock_performance
Purpose: Daily fact table combining all stock metrics for analysis and BI tools

Business Use Cases:
- Daily performance dashboards
- Trend analysis and charting
- Trading signal generation
- Risk monitoring

Grain: One row per ticker per trading day

SLA: Updated daily after market close (4:00 PM ET)

Last Updated: 2025-11-08
Author: T
#}

with stock_returns as (
    -- Source: Intermediate layer with daily returns
    select * from {{ ref('int_stock_returns') }}
),

moving_averages as (
    -- Source: Intermediate layer with technical indicators
    select * from {{ ref('int_moving_averages') }}
),

final as (
    select
        -- PRIMARY KEY
        r.ticker || '_' || r.trade_date as performance_key,
        
        -- DIMENSIONS
        r.ticker,
        r.company_name,
        r.trade_date,
        r.timestamp,
        
        -- PRICE METRICS
        r.open_price,
        r.high_price,
        r.low_price,
        r.close_price,
        
        -- VOLUME METRICS
        r.volume,
        r.vwap,
        r.num_transactions,
        
        -- RETURN METRICS
        r.daily_return_pct,
        r.intraday_range,
        r.intraday_volatility_pct,
        r.price_change_per_volume,
        
        -- TECHNICAL INDICATORS
        ma.sma_7_day,
        ma.sma_30_day,
        ma.sma_90_day,
        ma.avg_volume_7_day,
        ma.volatility_30_day,
        
        -- TRADING SIGNALS (derived)
        case 
            when ma.sma_7_day > ma.sma_30_day then 'BULLISH'
            when ma.sma_7_day < ma.sma_30_day then 'BEARISH'
            else 'NEUTRAL'
        end as trend_signal,
        
        case
            when r.close_price > ma.sma_7_day 
                and ma.sma_7_day > ma.sma_30_day 
                and ma.sma_30_day > ma.sma_90_day 
            then 'STRONG_BUY'
            when r.close_price < ma.sma_7_day 
                and ma.sma_7_day < ma.sma_30_day 
                and ma.sma_30_day < ma.sma_90_day 
            then 'STRONG_SELL'
            when r.close_price > ma.sma_30_day then 'BUY'
            when r.close_price < ma.sma_30_day then 'SELL'
            else 'HOLD'
        end as recommendation,
        
        case
            when r.volume > ma.avg_volume_7_day * 2 then 'HIGH'
            when r.volume < ma.avg_volume_7_day * 0.5 then 'LOW'
            else 'NORMAL'
        end as volume_indicator,
        
        -- METADATA
        current_timestamp() as dbt_updated_at
        
    from stock_returns r
    left join moving_averages ma
        on r.ticker = ma.ticker
        and r.trade_date = ma.trade_date
)

select * from final
order by ticker, trade_date desc