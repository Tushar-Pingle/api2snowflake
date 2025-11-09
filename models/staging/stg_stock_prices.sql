{{
    config(
        materialized='view'
    )
}}

with stock_data as (

    -- Apple
    select
        'AAPL' as ticker,
        'Apple Inc' as company_name,
        to_timestamp(T/1000) as timestamp,
        date(to_timestamp(T/1000)) as trade_date,
        O as open_price,
        H as high_price,
        L as low_price,
        C as close_price,
        V as volume,
        VW as vwap,
        N as num_transactions
    from {{ source("raw_stock_data", 'AAPL_STOCK_API')}}

    union all

    -- Microsoft
    select
        'MSFT' as ticker,
        'Microsoft Corporation' as company_name,
        to_timestamp(T/1000) as timestamp,
        date(to_timestamp(T/1000)) as trade_date,
        O as open_price,
        H as high_price,
        L as low_price,
        C as close_price,
        V as volume,
        VW as vwap,
        N as num_transactions
    from {{ source("raw_stock_data", 'MSFT_STOCK_API')}}
    
    union all

    -- Amazon
    select
        'AMZN' as ticker,
        'Amazon Inc' as company_name,
        to_timestamp(T/1000) as timestamp,
        date(to_timestamp(T/1000)) as trade_date,
        O as open_price,
        H as high_price,
        L as low_price,
        C as close_price,
        V as volume,
        VW as vwap,
        N as num_transactions
    from {{ source("raw_stock_data", 'AMZN_STOCK_API')}}

    union all

    -- Google
    select
        'GOOGL' as ticker,
        'Alphabet Inc' as company_name,
        to_timestamp(T/1000) as timestamp,
        date(to_timestamp(T/1000)) as trade_date,
        O as open_price,
        H as high_price,
        L as low_price,
        C as close_price,
        V as volume,
        VW as vwap,
        N as num_transactions
    from {{ source("raw_stock_data", 'GOOGL_STOCK_API')}}

    union all

    -- Meta/Facebook
    select
        'META' as ticker,
        'Meta Platforms Inc' as company_name,
        to_timestamp(T/1000) as timestamp,
        date(to_timestamp(T/1000)) as trade_date,
        O as open_price,
        H as high_price,
        L as low_price,
        C as close_price,
        V as volume,
        VW as vwap,
        N as num_transactions
    from {{ source("raw_stock_data", 'META_STOCK_API')}}

    union all

    -- Nvidia
    select
        'NVDA' as ticker,
        'Nvidia Corporation' as company_name,
        to_timestamp(T/1000) as timestamp,
        date(to_timestamp(T/1000)) as trade_date,
        O as open_price,
        H as high_price,
        L as low_price,
        C as close_price,
        V as volume,
        VW as vwap,
        N as num_transactions
    from {{ source("raw_stock_data", 'NVDA_STOCK_API')}}

    union all

    -- Nasdaq 100 ETF
    select
        'QQQ' as ticker,
        'Invesco QQQ Trust' as company_name,
        to_timestamp(T/1000) as timestamp,
        date(to_timestamp(T/1000)) as trade_date,
        O as open_price,
        H as high_price,
        L as low_price,
        C as close_price,
        V as volume,
        VW as vwap,
        N as num_transactions
    from {{ source("raw_stock_data", 'QQQ_STOCK_API')}}

    union all

    -- S&P 500 ETF
    select
        'SPY' as ticker,
        'SPDR S&P 500 ETF Trust' as company_name,
        to_timestamp(T/1000) as timestamp,
        date(to_timestamp(T/1000)) as trade_date,
        O as open_price,
        H as high_price,
        L as low_price,
        C as close_price,
        V as volume,
        VW as vwap,
        N as num_transactions
    from {{ source("raw_stock_data", 'SPY_STOCK_API')}}

    union all

    -- Tesla
    select
        'TSLA' as ticker,
        'Tesla Inc' as company_name,
        to_timestamp(T/1000) as timestamp,
        date(to_timestamp(T/1000)) as trade_date,
        O as open_price,
        H as high_price,
        L as low_price,
        C as close_price,
        V as volume,
        VW as vwap,
        N as num_transactions
    from {{ source("raw_stock_data", 'TSLA_STOCK_API')}}
)

select * from stock_data
order by ticker, trade_date