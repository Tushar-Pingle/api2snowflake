{{
    config(
        materialized='table',
        tags=['marts', 'dimension', 'summary'],
        meta={
            'owner': 'analytics',
            'Contains_PII': false
        }
    )
}}

{#
Model: dim_stock_summary
Purpose: Dimension table with latest stats and metadata for each stock

Grain: One row per ticker (latest data)

Last Updated: 2025-11-08
Author: T
#}

with daily_performance as (
    select * from {{ ref('fct_daily_stock_performance') }}
),

-- Get the latest date per ticker first
latest_dates as (
    select
        ticker,
        max(trade_date) as latest_trade_date
    from daily_performance
    group by ticker
),

-- Get latest values
latest_values as (
    select
        dp.ticker,
        dp.company_name,
        ld.latest_trade_date,
        dp.close_price as current_price,
        dp.volume as current_volume,
        dp.recommendation as current_recommendation,
        dp.trend_signal as current_trend
    from daily_performance dp
    inner join latest_dates ld
        on dp.ticker = ld.ticker
        and dp.trade_date = ld.latest_trade_date
),

-- Calculate 30-day stats
stats_30d as (
    select
        ticker,
        avg(daily_return_pct) as avg_return_30d,
        stddev(daily_return_pct) as volatility_30d,
        avg(volume) as avg_volume_30d,
        min(close_price) as low_30d,
        max(close_price) as high_30d,
        count(distinct trade_date) as total_trading_days
    from daily_performance
    where trade_date >= dateadd(day, -30, current_date)
    group by ticker
),

final as (
    select
        lv.ticker,
        lv.company_name,
        lv.latest_trade_date,
        lv.current_price,
        lv.current_volume,
        lv.current_recommendation,
        lv.current_trend,
        
        -- 30-day metrics
        s.avg_return_30d,
        s.volatility_30d,
        s.avg_volume_30d,
        s.low_30d,
        s.high_30d,
        
        -- Calculated metrics
        ((lv.current_price - s.low_30d) / nullif(s.high_30d - s.low_30d, 0)) * 100 as price_position_pct,
        (lv.current_volume / nullif(s.avg_volume_30d, 0)) * 100 as volume_vs_avg_pct,
        
        s.total_trading_days,
        current_timestamp() as dbt_updated_at
        
    from latest_values lv
    left join stats_30d s
        on lv.ticker = s.ticker
)

select * from final
order by ticker