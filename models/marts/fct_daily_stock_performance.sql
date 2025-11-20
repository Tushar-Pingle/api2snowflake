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
- Trading signal generation with advanced technical indicators
- Risk monitoring
- Quantitative trading strategy development

Grain: One row per ticker per trading day

Technical Indicators:
- RSI (Relative Strength Index) - 14-day momentum oscillator
- MACD (Moving Average Convergence Divergence) - Trend following
- Bollinger Bands - Volatility bands for overbought/oversold conditions
- SMA (Simple Moving Averages) - 7/30/90 day trends
- Volume analysis - Comparative volume metrics

SLA: Updated daily after market close (4:00 PM ET)

Last Updated: 2025-11-17
Author: T
#}

with stock_returns as (
    -- Source: Intermediate layer with daily returns
    select * from {{ ref('int_stock_returns') }}
),

moving_averages as (
    -- Source: Intermediate layer with SMA technical indicators
    select * from {{ ref('int_moving_averages') }}
),

technical_indicators as (
    -- Source: Intermediate layer with advanced technical indicators (RSI, MACD, Bollinger)
    select * from {{ ref('int_technical_indicators') }}
),

final as (
    select
        -- =============================================
        -- PRIMARY KEY
        -- =============================================
        r.ticker || '_' || r.trade_date as performance_key,
        
        -- =============================================
        -- DIMENSIONS
        -- =============================================
        r.ticker,
        r.company_name,
        r.trade_date,
        r.timestamp,
        
        -- =============================================
        -- PRICE METRICS
        -- =============================================
        r.open_price,
        r.high_price,
        r.low_price,
        r.close_price,
        
        -- =============================================
        -- VOLUME METRICS
        -- =============================================
        r.volume,
        r.vwap,
        r.num_transactions,
        
        -- =============================================
        -- RETURN METRICS
        -- =============================================
        r.daily_return_pct,
        r.intraday_range,
        r.intraday_volatility_pct,
        r.price_change_per_volume,
        
        -- =============================================
        -- SIMPLE MOVING AVERAGES
        -- =============================================
        ma.sma_7_day,
        ma.sma_30_day,
        ma.sma_90_day,
        ma.avg_volume_7_day,
        ma.volatility_30_day,
        
        -- =============================================
        -- ADVANCED TECHNICAL INDICATORS
        -- =============================================
        
        -- RSI (Relative Strength Index)
        ti.rsi_14_day,
        ti.rsi_signal,
        
        -- MACD (Moving Average Convergence Divergence)
        ti.macd_line,
        ti.macd_signal_line,
        ti.macd_histogram,
        ti.macd_signal,
        ti.macd_crossover,
        
        -- Bollinger Bands
        ti.bollinger_upper_band,
        ti.bollinger_middle_band,
        ti.bollinger_lower_band,
        ti.bollinger_width_pct,
        ti.bollinger_percent_b,
        ti.bollinger_position,
        
        -- Combined Signal from all indicators
        ti.combined_signal as advanced_signal,
        ti.signal_strength_score,
        
        -- =============================================
        -- BASIC TRADING SIGNALS (SMA-based)
        -- =============================================
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
        end as sma_recommendation,
        
        -- =============================================
        -- COMPOSITE RECOMMENDATION
        -- Combines SMA + RSI + MACD + Bollinger signals
        -- =============================================
        case
            -- STRONG BUY: Multiple bullish indicators aligned
            when ti.combined_signal = 'STRONG_BUY'
                and ma.sma_7_day > ma.sma_30_day
                and r.close_price > ma.sma_30_day
            then 'STRONG_BUY'
            
            -- STRONG SELL: Multiple bearish indicators aligned
            when ti.combined_signal = 'STRONG_SELL'
                and ma.sma_7_day < ma.sma_30_day
                and r.close_price < ma.sma_30_day
            then 'STRONG_SELL'
            
            -- BUY: Bullish signals from advanced indicators
            when ti.combined_signal = 'BUY'
                or (ti.rsi_signal = 'OVERSOLD' and ti.macd_signal = 'BULLISH')
            then 'BUY'
            
            -- SELL: Bearish signals from advanced indicators
            when ti.combined_signal = 'SELL'
                or (ti.rsi_signal = 'OVERBOUGHT' and ti.macd_signal = 'BEARISH')
            then 'SELL'
            
            -- Default to SMA-based recommendation
            else case
                when r.close_price > ma.sma_7_day 
                    and ma.sma_7_day > ma.sma_30_day 
                then 'BUY'
                when r.close_price < ma.sma_7_day 
                    and ma.sma_7_day < ma.sma_30_day 
                then 'SELL'
                else 'HOLD'
            end
        end as composite_recommendation,
        
        -- =============================================
        -- VOLUME INDICATORS
        -- =============================================
        case
            when r.volume > ma.avg_volume_7_day * 2 then 'HIGH'
            when r.volume < ma.avg_volume_7_day * 0.5 then 'LOW'
            else 'NORMAL'
        end as volume_indicator,
        
        -- Volume momentum
        round((r.volume / nullif(ma.avg_volume_7_day, 0) - 1) * 100, 2) as volume_vs_avg_pct,
        
        -- =============================================
        -- RISK METRICS
        -- =============================================
        case
            when ma.volatility_30_day > 3.0 then 'HIGH_RISK'
            when ma.volatility_30_day > 2.0 then 'MEDIUM_RISK'
            when ma.volatility_30_day > 1.0 then 'LOW_RISK'
            else 'VERY_LOW_RISK'
        end as volatility_risk_level,
        
        -- Bollinger Band squeeze (low volatility)
        case
            when ti.bollinger_width_pct < 5 then 'SQUEEZE'
            when ti.bollinger_width_pct > 20 then 'EXPANSION'
            else 'NORMAL'
        end as bollinger_squeeze_indicator,
        
        -- =============================================
        -- METADATA
        -- =============================================
        current_timestamp() as dbt_updated_at
        
    from stock_returns r
    left join moving_averages ma
        on r.ticker = ma.ticker
        and r.trade_date = ma.trade_date
    left join technical_indicators ti
        on r.ticker = ti.ticker
        and r.trade_date = ti.trade_date
)

select * from final
order by ticker, trade_date desc