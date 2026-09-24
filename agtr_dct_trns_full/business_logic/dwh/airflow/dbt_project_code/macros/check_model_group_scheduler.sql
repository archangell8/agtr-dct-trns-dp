-- noqa: disable=all
{% macro check_model_group_scheduler(tags, model_name) %}

    {% set schedule = var('dbt_run_schedule', none) %}
    {% set materialization = var('exec', none) %}
    {% if materialization != 'delta' %}
        {% do log(
            model_name ~ " - check_model_group_scheduler: Executing full load "
            "Returning True for all models",
            info=True
        ) %}
        {{ return(true) }}
    {% endif %}
    {% if schedule is none %}
        {% do log(
            model_name ~ " - check_model_group_scheduler: 'dbt_run_schedule' was not defined. "
            "Returning False",
            info=True
        ) %}
        {{ return(false) }}
    {% endif %}

    {# Check if the var dbt_run_schedule has string in values. #}
    {% for key, val in schedule.items() %}
        {% if not (val is sequence) %}
            {% do log(
                model_name ~ " - check_model_group_scheduler: schedule['" ~ key ~ "'] is not a "
                "list/sequence. Raising compile error.",
                info=True
            ) %}
            {{ exceptions.raise_compiler_error(
                "dbt_run_schedule: value for key '" ~ key ~ "' "
                "must be a list of integers (no strings)."
            ) }}
        {% endif %}
        {# verificar elementos da lista não são strings #}
        {% for elem in val %}
            {% if elem is string %}
                {% do log(
                    model_name ~ " - check_model_group_scheduler: schedule['" ~ key ~ "'] "
                    "contains a string element '" ~ elem ~ "'. "
                    "Raising compile error.", info=True
                ) %}
                {{ exceptions.raise_compiler_error(
                    "dbt_run_schedule: value for key '" ~ key ~ "' contains "
                    "string element '" ~ elem ~ "'. "
                    "All elements must be integers."
                ) }}
            {% endif %}
        {% endfor %}
    {% endfor %}

    {% do log(
        model_name ~ " - check_model_group_scheduler: 'dbt_run_schedule' values " ~ schedule,
        info=True
    ) %}

    {% if tags is not none %}
        {% do log(
            model_name ~ " - check_model_group_scheduler: Tags in the model: " ~ tags,
            info=True
        ) %}

        {% if tags is string %}
            {% set tags_list = [tags] %}
        {% else %}
            {% set tags_list = tags %}
        {% endif %}

        {# Check if any tags exists in 'dbt_run_schedule' variable #}
        {% set ns = namespace(exists_tags=None) %}

        {% for t in tags_list %}
            {% if schedule.get(t) is not none %}
                {% set ns.exists_tags = 'yes' %}
                {% break %}
            {% endif %}
        {% endfor %}

        {% if ns.exists_tags is none %}
            {% do log(
                model_name ~ " - check_model_group_scheduler: no tag has match with the "
                "'dbt_run_schedule' variable. Returning False",
                info=True
            ) %}
            {{ return(false) }}
        {% endif %}

    {% else %}
        {% do log(
            model_name ~ " - check_model_group_scheduler: no tag defined in the model. "
            "Returning False",
            info=True
        ) %}
        {{ return(false) }}
    {% endif %}

    {# Get all hour values based in the tags #}
    {% set allowed_list = [] %}
    {% for t in tags_list %}
        {% set allowed_for_tag = schedule.get(t) %}
        {% if allowed_for_tag is not none %}
            {% for tt in allowed_for_tag %}
                {% do allowed_list.append(tt) %}
            {% endfor %}
        {% endif %}
    {% endfor %}

    {# pega timestamp UTC do Snowflake em runtime, fallback para UTC local em compile-time #}
    {%
        set sql = """
            select to_char(
                convert_timezone('UTC', current_timestamp),
                'YYYY-MM-DD HH24:MI:SS'
            ) as utc_ts
        """
    %}
    {% if execute %}
        {% set results = run_query(sql) %}
        {% if not results %}
            {% do log(
                model_name ~ " - check_model_group_scheduler: run_query returned no results. "
                "Returning False.",
                info=True
            ) %}
            {{ return(false) }}
        {% endif %}
        {% set utc_ts = results.columns[0].values()[0] %}
        {% if utc_ts is none %}
            {% do log(
                model_name ~ " - check_model_group_scheduler: utc_ts is None. "
                "Returning False.",
                info=True
            ) %}
            {{ return(false) }}
        {% endif %}
    {% else %}
        {# compile-time fallback #}
        {%
            set utc_ts = modules.datetime.datetime.utcnow().strftime(
                "%Y-%m-%d %H:%M:%S"
            )
        %}
    {% endif %}

    {# converte string para hour #}
    {%
        set hour = modules.datetime.datetime.strptime(
            utc_ts, "%Y-%m-%d %H:%M:%S"
        ).hour
    %}

    {# comparação final #}
    {% if hour in allowed_list %}
        {% do log(
            model_name ~ " - check_model_group_scheduler: hour " ~ hour ~ " allowed in " ~
            allowed_list ~ ". Returning True.",
            info=True
        ) %}
        {{ return(true) }}
    {% else %}
        {% do log(
            model_name ~ " - check_model_group_scheduler: hour " ~ hour ~ " NOT allowed in " ~
            allowed_list ~ ". Returning False.",
            info=True
        ) %}
        {{ return(false) }}
    {% endif %}

{% endmacro %}