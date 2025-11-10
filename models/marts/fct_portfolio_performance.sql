{{
    config(
        materialized='table',
        tags=['marts', 'fact_table', 'portfolio'],
        meta={
            'owner': 'analytics',
            'Contains_PII': false
        }
    )
}}

{#
Model: fct_portfolio_performance
Purpose: Portfolio-level aggregated metrics

Grain: One row per trading day

Last Updated: 2025-11-08
Author: T
#}

with daily_performance as (
    select * from {{ ref('fct_daily_stock_performance') }}
),

-- Separate stocks from ETF benchmarks
individual_stocks as (
    select *
    from daily_performance
    where ticker not in ('SPY', 'QQQ')
),

benchmarks as (
    select
        trade_date,
        ticker,
        close_price,
        daily_return_pct
    from daily_performance
    where ticker in ('SPY', 'QQQ')
),

-- Aggregate portfolio metrics by date
portfolio_daily as (
    select
        trade_date,  -- ← FIXED: was trade_date.
        
        -- Stock count
        count(distinct ticker) as num_stocks,

        -- Price Metrics
        avg(close_price) as avg_stock_price,
        sum(close_price) as total_portfolio_value,

        -- Return Metrics
        avg(daily_return_pct) as portfolio_daily_return_pct,
        stddev(daily_return_pct) as portfolio_volatility,
        min(daily_return_pct) as worst_stock_return,
        max(daily_return_pct) as best_stock_return,

        -- Volume Metrics
        sum(volume) as total_volume,
        avg(volume) as avg_stock_volume,

        -- Technical Signals
        sum(case when recommendation = 'STRONG_BUY' then 1 else 0 end) as num_strong_buy,
        sum(case when recommendation = 'BUY' then 1 else 0 end) as num_buy,
        sum(case when recommendation = 'HOLD' then 1 else 0 end) as num_hold,
        sum(case when recommendation = 'SELL' then 1 else 0 end) as num_sell,
        sum(case when recommendation = 'STRONG_SELL' then 1 else 0 end) as num_strong_sell,

        sum(case when trend_signal = 'BULLISH' then 1 else 0 end) as num_bullish,
        sum(case when trend_signal = 'BEARISH' then 1 else 0 end) as num_bearish,
        sum(case when trend_signal = 'NEUTRAL' then 1 else 0 end) as num_neutral,

        -- Volatility Metrics
        avg(volatility_30_day) as avg_30d_volatility,
        avg(intraday_volatility_pct) as avg_intraday_volatility

    from individual_stocks
    group by trade_date
),

-- Add benchmark comparisons
final as (
    select
        p.trade_date,

        -- Portfolio Metrics
        p.num_stocks,
        p.avg_stock_price,
        p.total_portfolio_value,
        p.portfolio_daily_return_pct,
        p.portfolio_volatility,
        p.worst_stock_return,
        p.best_stock_return,
        p.total_volume,
        p.avg_stock_volume,

        -- Benchmark returns
        spy.daily_return_pct as spy_return_pct,
        qqq.daily_return_pct as qqq_return_pct,

        -- Relative performance (Alpha)
        p.portfolio_daily_return_pct - spy.daily_return_pct as alpha_vs_spy,
        p.portfolio_daily_return_pct - qqq.daily_return_pct as alpha_vs_qqq,

        -- Signal Distribution
        p.num_strong_buy,
        p.num_buy,
        p.num_hold,
        p.num_sell,
        p.num_strong_sell,

        p.num_bullish,
        p.num_bearish,
        p.num_neutral,

        -- Portfolio Sentiment Score (-100 to +100)
        ((p.num_strong_buy * 2 + p.num_buy * 1) - (p.num_sell * 1 + p.num_strong_sell * 2))
            / nullif(p.num_stocks, 0) * 100 as sentiment_score,

        -- Risk Metrics
        p.avg_30d_volatility,
        p.avg_intraday_volatility,

        -- Risk adjusted return (Sharpe-like ratio)
        case
            when p.portfolio_volatility > 0
            then p.portfolio_daily_return_pct / p.portfolio_volatility
            else null
        end as risk_adjusted_return,

        -- Market Regime Classification
        case
            when p.portfolio_daily_return_pct > 2 and p.avg_30d_volatility < 2 then 'BULL_MARKET'
            when p.portfolio_daily_return_pct < -2 and p.avg_30d_volatility > 3 then 'BEAR_MARKET'
            when p.avg_30d_volatility > 4 then 'HIGH_VOLATILITY'
            when abs(p.portfolio_daily_return_pct) < 0.5 then 'SIDEWAYS'
            else 'NORMAL'
        end as market_regime,

        -- Metadata
        current_timestamp() as dbt_updated_at
    
    from portfolio_daily p
    left join benchmarks spy
        on p.trade_date = spy.trade_date
        and spy.ticker = 'SPY'
    left join benchmarks qqq
        on p.trade_date = qqq.trade_date
        and qqq.ticker = 'QQQ'  -- ← FIXED: was spy.ticker
)

select * from final
order by trade_date desc