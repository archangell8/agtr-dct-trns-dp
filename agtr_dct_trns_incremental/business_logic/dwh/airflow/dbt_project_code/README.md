## Introduction

This repository stores all the source code for the transformation process of the Digital Control Tower (DCT) project, using Cargill's Minerva Engineering Framework (MEF).

This project uses [dbt](https://www.getdbt.com/) to make the transformations and [Snowflake](https://www.snowflake.com/) as the data warehouse to load the results.

It also leverages [sqlfluff](https://docs.sqlfluff.com/) for SQL linting and code quality.


## Required Tools

- **Python** (recommended: >=3.8)
- **pip** (Python package manager)
- **git** (for version control)
- **dbt CLI** (installed via pip)
- **Snowflake** account (credentials required)

**Optional but recommended:**
- **virtualenv** (for isolated Python environments)


## Required Skills

To work efficiently with this project, you are expected to have basic proficiency or familiarity with the following skills and concepts:

- **SQL**: Ability to write and read SQL queries, especially for data transformation.
- **Data Warehousing**: Understanding of data warehouse concepts, ideally with experience on Snowflake.
- **Python Basics**: For managing environments and dependencies.
- **Version Control with Git**: Cloning repositories, creating branches, and basic commit/push workflows.
- **dbt**: Understanding of dbt models, seeds, tests, and basic CLI usage.
- **Jinja**: Familiarity with [Jinja](https://jinja.palletsprojects.com/) templating, especially for developing dbt macros and advanced SQL generation.
- **Code Linting**: Using linters like sqlfluff to enforce code quality.
- **Environment Management**: Creating and activating Python virtual environments on Linux/macOS or Windows.
- **CI/CD with Vela**: Basic knowledge of the [Vela](https://vela.cglcloud.in/) tool to understand and manage CI/CD processes, including pipeline execution, debugging, and deployments.


## Setup Environment

Below are step-by-step instructions to set up your environment on **Linux/macOS** and **Windows**.

### Linux/macOS

1. **Clone the repository**
   ```bash
   git clone https://git.cglcloud.com/MinervaEngineering/miw-casc-digital-control-tower-trns.git
   cd miw-casc-digital-control-tower-trns/
   ```
2. **Create a virtual environment**

   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install requirements**

   ```bash
   pip install -r requirements.txt
   ```

4. **Set environment variables for certificates**  
   Download the `ca_bundle.pem` file from the provided [link](https://cglcloud.jfrog.io/artifactory/outbound_proxies/certbundle/ca_bundle.pem) and set the following environment variables, replacing `/path/to/ca_bundle.pem` with the actual file path:
   ```bash
   export REQUESTS_CA_BUNDLE=/path/to/ca_bundle.pem
   export AWS_CA_BUNDLE=/path/to/ca_bundle.pem
   export SSL_CERT_FILE=/path/to/ca_bundle.pem
   ```

5. **Set environment variables for proxy**
   ```bash
   export HTTP_PROXY="http://web.prod.proxy.cargill.com:4300"
   export HTTPS_PROXY="http://web.prod.proxy.cargill.com:4300"
   export ALL_PROXY="http://web.prod.proxy.cargill.com:4300"
   ```

6. **Configure SQL Fluff (Lint)**

    If you use VSCode Editor, you can configure sqlfluff to validate .sql automatically
    using this [extension](https://marketplace.visualstudio.com/items?itemName=dorzey.vscode-sqlfluff).

### Windows

1. **Clone the repository**
    ```powershell
    git clone https://git.cglcloud.com/MinervaEngineering/miw-casc-digital-control-tower-trns.git
    cd miw-casc-digital-control-tower-trns/
    ```

2. **Create a virtual environment**

   ```powershell
   python3 -m venv venv
   .\venv\Scripts\activate
   ```

3. **Install requirements**

   ```powershell
   pip install -r requirements.txt
   ```

4. **Set environment variables for certificates**  
   Download the `ca_bundle.pem` file from the provided [link](https://cglcloud.jfrog.io/artifactory/outbound_proxies/certbundle/ca_bundle.pem) and following environment variables in your PowerShell session, replacing `C:\path\to\ca_bundle.pem` with the actual file path:
   ```powershell
   $env:REQUESTS_CA_BUNDLE="C:\path\to\ca_bundle.pem"
   $env:AWS_CA_BUNDLE="C:\path\to\ca_bundle.pem"
   $env:SSL_CERT_FILE="C:\path\to\ca_bundle.pem"
   ```

5. **Set environment variables for proxy**
   ```powershell
   $env:HTTP_PROXY="http://web.prod.proxy.cargill.com:4300"
   $env:HTTPS_PROXY="http://web.prod.proxy.cargill.com:4300"
   $env:ALL_PROXY="http://web.prod.proxy.cargill.com:4300"
   ```

6. **Configure SQL Fluff (Lint)**

    If you use VSCode Editor, you can configure sqlfluff to validate .sql automatically using this [extension](https://marketplace.visualstudio.com/items?itemName=dorzey.vscode-sqlfluff).


## DBT Configuration and Validation

Before running any dbt commands, you need to configure your dbt profile to connect to Snowflake. The profile configuration tells dbt how to connect to each environment (dev, qas, prod).

> **Important:**  
> If you are using a Python virtual environment (venv), make sure it is **activated** before running any dbt or Python commands.  
> - On **Linux/macOS**, activate with: `source venv/bin/activate`
> - On **Windows**, activate with: `.\venv\Scripts\activate`
>
> You should see the virtual environment name (e.g., `(venv)`) at the beginning of your terminal prompt when it is activated.


### 1. Login on VPN

### 2. Configure your dbt profile

This project provides a `profile.yml` file inside the `dbt_project_code` directory.  
Open this file and update the configuration with your actual Snowflake credentials and environment details.  
Replace all placeholders (`<your_user>`, `<your_role>`, `<your_database>`, `<your_warehouse>`, `<your_schema>`) with your real values.

**Example (edit `dbt_project_code/profile.yml`):**

```yaml
mef_dct_project:
  outputs:
    dev:
      type: snowflake
      account: cargill-dev
      user: <your_user>
      role: <your_role>
      authenticator: externalbrowser
      database: <your_database>
      warehouse: <your_warehouse>
      schema:  <your_schema>
      threads: 1
      client_session_keep_alive: False
      connect_retries: 0
      connect_timeout: 10
      retry_on_database_errors: False
      retry_all: False
      reuse_connections: False

    qas:
      type: snowflake
      account: cargill-dev
      user: <your_user>
      role: <your_role>
      authenticator: externalbrowser
      database: <your_database>
      warehouse: <your_warehouse>
      schema:  <your_schema>
      threads: 1
      client_session_keep_alive: False
      connect_retries: 0
      connect_timeout: 10
      retry_on_database_errors: False
      retry_all: False
      reuse_connections: False

    prod:
      type: snowflake
      account: cargill-prod
      user: <your_user>
      role: <your_role>
      authenticator: externalbrowser
      database: <your_database>
      warehouse: <your_warehouse>
      schema: <your_schema>
      threads: 1
      reuse_connections: True

  target: dev
```

**Note:**  
- The `target` key at the bottom defines the default environment dbt will use (e.g., `dev`).  
- You can switch the target by updating this key or by using the `--target` flag in dbt commands.

### 3. Validate your dbt connection

To ensure your connection is correctly configured, run the following command from the root of your dbt project (where the `dbt_project_code` directory is located):

```bash
dbt debug
```

- If everything is set up correctly, you should see a success message indicating dbt was able to connect to your Snowflake environment.
- If there are errors, review the error messages and check your `profile.yml` settings.

## Running the dbt Project

After configuring your environment and your profile, you are ready to execute dbt commands. All commands below should be executed from the root of your project (where the `dbt_project_code` directory is located), and with your virtual environment activated if you are using one.

**Note**: You need to be logged into the VPN.

### 1. Run the Entire Project

To execute all models in the project for the default target (as defined in your `profile.yml`):

```bash
dbt run --project-dir dbt_project_code
```

To run for a specific target (e.g., `prod`, `qas`, or `dev`):

```bash
dbt run --project-dir dbt_project_code --target <target>
```
Replace `<target>` with `dev`, `qas`, or `prod` as needed.

### 2. Run a Specific Directory of Models

To execute all models inside a directory (e.g., `models/master_data`):

```bash
dbt run --project-dir dbt_project_code --models staging
```

You can specify nested directories as well, for example:

```bash
dbt run --project-dir dbt_project_code --models master_data/mart
```

### 3. Run a Specific Model and Its Dependencies

To run a single model and all its dependencies (upstream and downstream):

```bash
dbt run --project-dir dbt_project_code --models <model_name>+
```
- `<model_name>` is the name of the model file without the `.sql` extension.

- To run only the model and its upstream dependencies (ancestors):
  ```bash
  dbt run --project-dir dbt_project_code --models +<model_name>
  ```

- To run only the model:
  ```bash
  dbt run --project-dir dbt_project_code --models <model_name>
  ```


### 4. Run Tests

To execute tests for all models:

```bash
dbt test --project-dir dbt_project_code
```

To test only specific models or directories, use:

```bash
dbt test --project-dir dbt_project_code --models <model_name>
```

### 5. Additional Useful Commands

- **Compile SQL files without executing:**
  ```bash
  dbt compile --project-dir dbt_project_code
  ```

- **Show model dependencies graphically:**
  ```bash
  dbt docs generate --project-dir dbt_project_code
  dbt docs serve --project-dir dbt_project_code
  ```


## MEF Configurations
The configuration of the pipeline generated by the MEF tool is directly related to the definitions of the ```.minerva.yml``` file.

This file is used to build the DAG for the production and development airflow. This DAG uses the [Cosmos](https://www.astronomer.io/cosmos/) framework to generate the dbt pipeline and the meta-information from the ```.minerva.yml``` to generate the pipeline. The DAG will be created with the pattern name ```dbt__dag__<repository_name>```.

Below are the links to the development and production airflow:
- [Production](https://mef-airflow-ccp.cglcloud.com/home)
- [Development](https://mef-airflow-ccp.dev.cglcloud.in/home)

Below, you can briefly understand each tag in the file and its use within the framework.

```yaml
team: casc-latam-data-engineering # team with project privilege
kind: data
target: snowflake # warehouse target
env:
  dev:
    database: CASC_DIGITAL_CONTROL_TOWER_DEV # dev database used on the airflow
    schema: DIGITAL_CONTROL_TOWER_TRNS # dev schema used on the airflow
  prod:
    database: CASC_DIGITAL_CONTROL_TOWER_PRD # prod database used on the airflow
    schema: DIGITAL_CONTROL_TOWER_TRNS # prod databased used on the airflow
transformation:
  type: dbt # type of transformation
  projectCode: "/dbt_project_code/" # project code repository
  models:
    - name: vw_customer_final # name of the model / table
      # tag related to unload data in s3 files
      unload:
        # stage to snowflake connect on s3
        stage_dev: "@CASC_DIGITAL_CONTROL_TOWER_QAS.DIGITAL_CONTROL_TOWER_TRNS.STG_MINERVA_DEV_DIGITAL_CONTROL_TOWER_OUT"
        stage_prod: "@CASC_DIGITAL_CONTROL_TOWER_PRD.DIGITAL_CONTROL_TOWER_TRNS.STG_MINERVA_PRD_DIGITAL_CONTROL_TOWER_OUT"
        stage_path: "/out/Customer.csv" # filename loaded on s3
        format: 'CSV' # format file
        header: false # boolean to add header or not
        single: true # boolean to define if will be generated a single or multiple files
        overwrite: true # boolean to define if the file generated will be replace another if exists
        # unload mode
        # mode: incremental
        mode: full
        # column used on unload process
        check_column: cdp_timestamp_full
        # check_column: cdp_timestamp_inc
        max_file_size: 999999999 # filesize
        initial_load: true # boolean to define if the initial load capability is enable
        # list of columns to generated on the files
        columns:
          - customerid
          - taxid
          - name
          - status
          - address
          - complement
          - neighborhood
          - zipcode
          - city
          - state
          - country
          - market
          - territory
          - segmentation
          - customergroup
          - customergroupdescription
          - creditblocked
          - cdp_timestamp_o9
        # file configurations
        format_configs:
            record_delimiter: '\r\n'
            field_delimiter: "|"
            compression: "NONE"
            binary_format: "UTF8"
  scheduler:
    type: airflow # shceduler used
    schedule: '20 3 * * *' # crontab to execute the code
    sync: zip_file # docker, git or zip_file
    email: -MINERVA-OPS-ALL@Cargill.com # future feature with alertOnFailure
  alerts:
    - type: teams
      # teams webhook
      success_channel: ""
      failure_channel: ""
```

**Note:** it is important to highlight that the schema and database used by airflow is extracted from the ```.minerva.yml``` file, however the warehouse information is extracted from the ```profile.yml``` file of the dbt project.

## Deploying Changes

The project deployment strategies follow the following image, which illustrates the sequence of steps to ensure consistent deployment.

![prod deployment vela](./images/deployment-steps.png)

In short, in the scenario where it is necessary to make a deployment based on an incident or issue, it is necessary to first execute the local dbt project with the changes (pointing to the snowflake development database), and request the evaluation of the solution from the D&A team. Once the changes have been approved, the flow suggests that a deployment be made to the development airflow first (which will execute the dbt project in the snowflake QaS database), and only then evolve the changes to a production deployment. It is important to note that all changes and tests must be properly validated before performing the deployments, thus minimizing possible failures.

To perform deployment actions in development and production, you must be in the [casc latam team](https://git.cglcloud.com/MinervaEngineering/lighthouse/blob/main/casc-latam.tf).

The repository use the [minerva-pipeline](https://git.cglcloud.com/Minerva/minerva-pipeline) project to perform pre-validations of the project's configuration and governance, as well as create a repository interface with the Airflow API to submit new changes that are developed. This is triggered from the steps defined in the `.vela.yml` file:
  - `plan-on-pr`: a PR to main, where `apply: false`
  - `deploy-dev`: a PUSH to main, where `apply: true`
  - `deploy-dev-rc`: a TAG of a release candidate (`v*.*.*-rc*`), where `apply: true`.
  - `deploy-prod`: a vela DEPLOYMENT of the release candidate TAG, where `apply: true`, i.e.

In practice, to make a deployment in development, it is necessary to evolve the project to the main branch, and to perform a deployment in production it is necessary do a deployment action in the [vela tool](https://vela.cglcloud.in/MinervaEngineering) as show in the following images.

---

![prod deployment vela](./images/deployment-prod.png)

### Links and References

- [dbt-core](https://docs.getdbt.com/docs/installation)

- [dbt-profiles](https://docs.getdbt.com/docs/configure-your-profile)