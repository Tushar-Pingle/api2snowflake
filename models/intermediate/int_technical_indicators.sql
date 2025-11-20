-- =============================================
-- Technical Indicators Model
-- =============================================
-- Purpose: Calculate advanced technical indicators for trading analysis
-- 
-- Indicators Included:
-- 1. RSI (Relative Strength Index) - Momentum oscillator (0-100 scale)
-- 2. MACD (Moving Average Convergence Divergence) - Trend following
-- 3. Bollinger Bands - Volatility bands
--
-- Business Use: Identify overbought/oversold conditions and trend strength
-- =============================================

WITH price_data AS (
    SELECT 
        ticker,
        trade_date,
        close_price,
        LAG(close_price, 1) OVER (PARTITION BY ticker ORDER BY trade_date) AS prev_close
    FROM {{ ref('stg_stock_prices') }}
),

price_changes AS (
    SELECT 
        ticker,
        trade_date,
        close_price,
        prev_close,
        close_price - prev_close AS price_change,
        CASE 
            WHEN close_price > prev_close THEN close_price - prev_close 
            ELSE 0 
        END AS gain,
        CASE 
            WHEN close_price < prev_close THEN prev_close - close_price 
            ELSE 0 
        END AS loss
    FROM price_data
    WHERE prev_close IS NOT NULL
),

-- =============================================
-- RSI Calculation (14-day period)
-- =============================================
rsi_calc AS (
    SELECT 
        ticker,
        trade_date,
        close_price,
        price_change,
        gain,
        loss,
        -- Calculate 14-day average gain and loss
        AVG(gain) OVER (
            PARTITION BY ticker 
            ORDER BY trade_date 
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ) AS avg_gain_14,
        AVG(loss) OVER (
            PARTITION BY ticker 
            ORDER BY trade_date 
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ) AS avg_loss_14
    FROM price_changes
),

rsi_with_values AS (
    SELECT 
        ticker,
        trade_date,
        close_price,
        price_change,
        avg_gain_14,
        avg_loss_14,
        -- RSI formula: 100 - (100 / (1 + RS))
        -- Where RS = Average Gain / Average Loss
        CASE 
            WHEN avg_loss_14 = 0 THEN 100
            WHEN avg_gain_14 = 0 THEN 0
            ELSE 100 - (100 / (1 + (avg_gain_14 / avg_loss_14)))
        END AS rsi_14,
        -- RSI interpretation
        CASE 
            WHEN avg_loss_14 = 0 THEN 'EXTREMELY_OVERBOUGHT'
            WHEN avg_gain_14 = 0 THEN 'EXTREMELY_OVERSOLD'
            WHEN 100 - (100 / (1 + (avg_gain_14 / avg_loss_14))) >= 70 THEN 'OVERBOUGHT'
            WHEN 100 - (100 / (1 + (avg_gain_14 / avg_loss_14))) <= 30 THEN 'OVERSOLD'
            ELSE 'NEUTRAL'
        END AS rsi_signal
    FROM rsi_calc
),

-- =============================================
-- MACD Calculation
-- =============================================
-- MACD = 12-day EMA - 26-day EMA
-- Signal Line = 9-day EMA of MACD
-- Histogram = MACD - Signal Line
-- =============================================
exponential_moving_averages AS (
    SELECT 
        ticker,
        trade_date,
        close_price,
        -- 12-day EMA (fast line)
        AVG(close_price) OVER (
            PARTITION BY ticker 
            ORDER BY trade_date 
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS ema_12,
        -- 26-day EMA (slow line)
        AVG(close_price) OVER (
            PARTITION BY ticker 
            ORDER BY trade_date 
            ROWS BETWEEN 25 PRECEDING AND CURRENT ROW
        ) AS ema_26
    FROM {{ ref('stg_stock_prices') }}
),

macd_calc AS (
    SELECT 
        ticker,
        trade_date,
        close_price,
        ema_12,
        ema_26,
        ema_12 - ema_26 AS macd_line,
        -- Signal line (9-day EMA of MACD)
        AVG(ema_12 - ema_26) OVER (
            PARTITION BY ticker 
            ORDER BY trade_date 
            ROWS BETWEEN 8 PRECEDING AND CURRENT ROW
        ) AS macd_signal_line
    FROM exponential_moving_averages
),

macd_with_histogram AS (
    SELECT 
        ticker,
        trade_date,
        close_price,
        macd_line,
        macd_signal_line,
        macd_line - macd_signal_line AS macd_histogram,
        -- MACD interpretation
        CASE 
            WHEN macd_line > macd_signal_line AND (macd_line - macd_signal_line) > 0 THEN 'BULLISH'
            WHEN macd_line < macd_signal_line AND (macd_line - macd_signal_line) < 0 THEN 'BEARISH'
            ELSE 'NEUTRAL'
        END AS macd_signal,
        -- Crossover detection
        CASE 
            WHEN macd_line > macd_signal_line 
                 AND LAG(macd_line) OVER (PARTITION BY ticker ORDER BY trade_date) <= LAG(macd_signal_line) OVER (PARTITION BY ticker ORDER BY trade_date) 
                 THEN 'BULLISH_CROSSOVER'
            WHEN macd_line < macd_signal_line 
                 AND LAG(macd_line) OVER (PARTITION BY ticker ORDER BY trade_date) >= LAG(macd_signal_line) OVER (PARTITION BY ticker ORDER BY trade_date)
                 THEN 'BEARISH_CROSSOVER'
            ELSE 'NO_CROSSOVER'
        END AS macd_crossover
    FROM macd_calc
),

-- =============================================
-- Bollinger Bands Calculation
-- =============================================
-- Middle Band = 20-day SMA
-- Upper Band = Middle + (2 * 20-day StdDev)
-- Lower Band = Middle - (2 * 20-day StdDev)
-- =============================================
bollinger_bands AS (
    SELECT 
        ticker,
        trade_date,
        close_price,
        -- Middle band (20-day SMA)
        AVG(close_price) OVER (
            PARTITION BY ticker 
            ORDER BY trade_date 
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS bb_middle,
        -- Standard deviation (20-day)
        STDDEV(close_price) OVER (
            PARTITION BY ticker 
            ORDER BY trade_date 
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS bb_stddev
    FROM {{ ref('stg_stock_prices') }}
),

bollinger_with_bands AS (
    SELECT 
        ticker,
        trade_date,
        close_price,
        bb_middle,
        bb_stddev,
        bb_middle + (2 * bb_stddev) AS bb_upper,
        bb_middle - (2 * bb_stddev) AS bb_lower,
        -- Band width (volatility indicator)
        (2 * bb_stddev) / NULLIF(bb_middle, 0) * 100 AS bb_width_pct,
        -- %B indicator (position within bands)
        (close_price - (bb_middle - (2 * bb_stddev))) / NULLIF((4 * bb_stddev), 0) * 100 AS bb_percent_b,
        -- Bollinger Band interpretation
        CASE 
            WHEN close_price > bb_middle + (2 * bb_stddev) THEN 'ABOVE_UPPER_BAND'
            WHEN close_price < bb_middle - (2 * bb_stddev) THEN 'BELOW_LOWER_BAND'
            WHEN close_price > bb_middle THEN 'ABOVE_MIDDLE'
            ELSE 'BELOW_MIDDLE'
        END AS bb_position
    FROM bollinger_bands
),

-- =============================================
-- Combine All Indicators
-- =============================================
final AS (
    SELECT 
        r.ticker,
        r.trade_date,
        r.close_price,
        
        -- RSI Indicators
        ROUND(r.rsi_14, 2) AS rsi_14_day,
        r.rsi_signal,
        
        -- MACD Indicators
        ROUND(m.macd_line, 4) AS macd_line,
        ROUND(m.macd_signal_line, 4) AS macd_signal_line,
        ROUND(m.macd_histogram, 4) AS macd_histogram,
        m.macd_signal,
        m.macd_crossover,
        
        -- Bollinger Bands
        ROUND(b.bb_upper, 2) AS bollinger_upper_band,
        ROUND(b.bb_middle, 2) AS bollinger_middle_band,
        ROUND(b.bb_lower, 2) AS bollinger_lower_band,
        ROUND(b.bb_width_pct, 2) AS bollinger_width_pct,
        ROUND(b.bb_percent_b, 2) AS bollinger_percent_b,
        b.bb_position AS bollinger_position,
        
        -- Combined Trading Signal
        CASE 
            WHEN r.rsi_signal = 'OVERSOLD' 
                 AND m.macd_signal = 'BULLISH' 
                 AND b.bb_position = 'BELOW_LOWER_BAND' 
                 THEN 'STRONG_BUY'
            WHEN r.rsi_signal = 'OVERBOUGHT' 
                 AND m.macd_signal = 'BEARISH' 
                 AND b.bb_position = 'ABOVE_UPPER_BAND' 
                 THEN 'STRONG_SELL'
            WHEN r.rsi_signal = 'OVERSOLD' 
                 AND m.macd_crossover = 'BULLISH_CROSSOVER' 
                 THEN 'BUY'
            WHEN r.rsi_signal = 'OVERBOUGHT' 
                 AND m.macd_crossover = 'BEARISH_CROSSOVER' 
                 THEN 'SELL'
            ELSE 'HOLD'
        END AS combined_signal,
        
        -- Signal Strength Score (0-100)
        CASE 
            WHEN r.rsi_signal IN ('OVERSOLD', 'EXTREMELY_OVERSOLD') THEN 33
            WHEN r.rsi_signal IN ('OVERBOUGHT', 'EXTREMELY_OVERBOUGHT') THEN -33
            ELSE 0
        END +
        CASE 
            WHEN m.macd_signal = 'BULLISH' THEN 33
            WHEN m.macd_signal = 'BEARISH' THEN -33
            ELSE 0
        END +
        CASE 
            WHEN b.bb_position = 'BELOW_LOWER_BAND' THEN 34
            WHEN b.bb_position = 'ABOVE_UPPER_BAND' THEN -34
            ELSE 0
        END AS signal_strength_score
        
    FROM rsi_with_values r
    INNER JOIN macd_with_histogram m 
        ON r.ticker = m.ticker 
        AND r.trade_date = m.trade_date
    INNER JOIN bollinger_with_bands b 
        ON r.ticker = b.ticker 
        AND r.trade_date = b.trade_date
)

SELECT * FROM final