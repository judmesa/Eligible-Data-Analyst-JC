with source as (
    select *
    from {{ ref('mortgages') }}
)

select 
    mortgage_id,
    firm_alias as lender,
    mortgage_type,
    mortgage_state,
    cast(mortgage_expiry_date as date) as expiry_date,
    cast(mortgage_closed_date as date) as closed_date,

    -- quality check
    case when mortgage_state = 'open' and mortgage_closed_date is not null then true else false
    end as dq_open_with_closed_date
from source