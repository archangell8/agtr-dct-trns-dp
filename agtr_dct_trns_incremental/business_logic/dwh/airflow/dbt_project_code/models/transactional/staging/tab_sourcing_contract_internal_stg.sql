-- noqa: disable=all
{{
    config(
        materialized='table'
    )
}}


-- Essa modelo foi criado para intermediar o uso da coluna contractnumber.
-- Devido aos ajustes realizados na sourcing_contract, que adiciona o
--   destination no id e no contractnumber, será gerado diversos contratos
--   para o mesmo contractnumber.
-- Com isso, conforme sugerido pelo analista Vitor Souza, deve-se considerar
--   o primeiro registro para daca contractnumber único.
SELECT
    ID,
    CONTRACTNUMBER_INTERNAL AS CONTRACTNUMBER,
    SUPPLIERID,
    SOURCE,
    FARM,
    DESTINATION,
    DELIVERY,
    DELIVERYUNITID,
    ORIGINATION,
    TRANSMODE,
    FREIGHTTYPE,
    DELIVERYSTART,
    DELIVERYEND,
    STATUS,
    FISCALCONDITION,
    TYPE,
    PAYMENTDATE,
    PAYMENTDETAILS,
    SALESREP,
    GLOBALINVOICE
FROM {{ ref('sourcing_contract_details_master') }}
QUALIFY
    ROW_NUMBER() OVER (
        PARTITION BY CONTRACTNUMBER_INTERNAL
        ORDER BY ID DESC
    ) = 1
