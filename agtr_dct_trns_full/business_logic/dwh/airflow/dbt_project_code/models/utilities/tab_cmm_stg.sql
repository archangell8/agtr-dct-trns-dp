{{
    config(
        materialized='table'
    )
}}

-- MODEL TO MATERIALIZE CMM VIEW.
-- THIS COULD BE IMPROVE THE TRANSPORTATION SCHEDULE MODEL.
SELECT *
FROM {{ source('cmm', 'VW_CMM') }}
