# casc-dct-trns-dp

Transformation code for the Digital Control Tower schemas

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
   git clone https://git.cglcloud.com/Minerva/agtr-dct-trns-dp.git
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
    git clone https://git.cglcloud.com/Minerva/agtr-dct-trns-dp.git
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
  If doesn't works, go to pip folder (usually something like "C:\Users\youruser\AppData\Roaming\pip\", where the ca_bundle.pem is originally located), open file `pip.ini` and change the variable "cert" to de correct path where
  it's located, eg.:

  Original: `cert = C:\Users\\AppData\Roaming\pip\ca_bundle.pem`
  Change to: `cert = C:\Users\youruser\AppData\Roaming\pip\ca_bundle.pem`

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


## Testing this project in a lower environment

This project provides a `profile.yml` file inside the `dbt_project_code` directory.

Open this file and update the configuration with your actual Snowflake credentials and environment details. Replace all placeholders (<your_user>, <your_role>, <your_database>, <your_warehouse>, <your_schema>) with your real values.

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
      schema: <your_schema>
      threads: 1
      client_session_keep_alive: False
      connect_retries: 0
      connect_timeout: 10
      retry_on_database_errors: False
      retry_all: False
      reuse_connections: False

  target: dev
```
> [!TIP]
> The `target` key at the bottom defines the default environment dbt will use (e.g., `dev`).
> You can switch the target by updating this key or by using the `--target` flag in dbt commands.
>
> The `threads` key defines how many concurrencies is allowed and by default is 1.
> You can change it by setting on `profiles.yml` file or using the `--threads` flag on command line.

- If you are testing against a different `datbase`, `schema`, `warehouse` or
  `role`, make those edits as well in the profiles.yml. If you are simply running against the
  pre-defined IMDB databases, schemas, etc, no change is needed.

- Ensure your profile is setup correctly from the command line:

  ```bash
  dbt debug --profiles-dir dbt_project_code --project-dir dbt_project_code
  ```
  - If everything is set up correctly, you should see a success message indicating dbt was able to connect to your Snowflake environment.
  - If there are errors, review the error messages and check your `profile.yml` settings.

> [!NOTE]
> When you are inside "dbt_project_code" folder, it's not required to define the flags --profiles-dir and --project-dir on the command line

- Run the models:
  - Run all models:
      ```bash
      dbt run --profiles-dir dbt_project_code --project-dir dbt_project_code
      ```
  - Run a especific model:
    ```bash
    dbt run -s model_name
    ```
> [!TIP]
> You can run the dependencies of the model by adding `+` symbol at the start of the model name, or all the models that depends on it by adding `+` symbol at the end of the model name.

  - Run a especific folder (eg.: "master_data"):
    ```bash
    dbt run -s master_data --threads 10
    ```
- Test the output of the models:

  ```bash
  dbt test --profiles-dir dbt_project_code --project-dir dbt_project_code
  ```

- Documentation:
  - Generate documentation for the project:

    ```bash
    dbt docs generate --profiles-dir dbt_project_code --project-dir dbt_project_code
    ```

  - View the documentation for the project on a localhost:

    ```bash
    dbt docs serve --profiles-dir dbt_project_code --project-dir dbt_project_code
    ```
## Deploying Changes

- The `minerva-pipeline` is triggered from the steps defined in the `.vela.yml` file:
  - `plan-on-pr`: a PR to main, where `apply: false`
  - `deploy-dev`: a PUSH to dev, where `apply: true`
  - `deploy-qas`: a PUSH to qas, where `apply: true`
  - `deploy-prod`: a PUSH to main, where `apply: true`

## Essential Git Repositories and links

- Data source ingestion:
[cdp3-ingestion](https://git.cglcloud.com/DataPlatform/cdp3_managed_ingestion)

- Issues for MIF and MEF: [minerva-central/issues](https://git.cglcloud.com/Minerva/minerva-central/issues)

- Functional documentation: [DCT/Function-Designs](https://git.cglcloud.com/DigitalControlTower-Data/Function-Designs/wiki)

- Monitoring alerts:
  - [git-dct-monitoring](https://git.cglcloud.com/DBI/cascsa-dct-monitoring)
  - [rundeck-dct](https://peanut-rundeck.cargill.com:8000/project/cascsa_prd/jobs/Digital%20Control%20Tower%20-%20Snowflake)

- Astronomer: [dct-astro](https://cloud.astronomer.io/cmfdhy8ya23pr01mvbgphsarv/dags?owner=casc-latam-data-engineering&name=dct)

- Snowflake: [snowflake](https://app.snowflake.com/)


## References

- [dbt-core](https://docs.getdbt.com/docs/installation)

- [dbt-profiles](https://docs.getdbt.com/docs/configure-your-profile)