## Admin DB

Simple partial database structure that reproduce Trello application (by Atlassian) data model.
This schema include the following databases:

* `_App`: Main database
  - `Users`: Authenticable users
  - `Boards`: Trello boards
  - `Members`: Board members
  - `Columns`: Board columns
  - `Cards`: Board cards
* `_Security_`: Sensitive data related to users such as authentication data (ex: passwd, keys...)
  - `Authentication`: Contains user authentication informations

### How to use it

In first when you need to INSERT an user YOU MUST USE the stored procedure `_App.create_user(...)`, this procedure will automatically generate two record :
  * The new entry in `_App.Users`
  * The new authentication data in `_Security.Authentications` matching to the newly created user.

When you need to create a new board YOU MUST USE the stored procedure `_App.create_board(...)`, this procedure will automatically verify if the given user as owner haven't reach his 5 board before inserting new one into tables. Otherwise throw a custom error (SqlState: `02TMB`).

### Roles & Users

#### Roles

* `R_API`: Role for API (permissions for common CRUD operations excluding security sensitive data)
* `R_AUTH`: Role for API (permissions for only security related CRUD operations)
* `R_ADMIN`: Both `R_API` and `R_AUTH`

#### Users

* `U_AUTH@%`
  * Password: `U_AUTH`
  * Role: `R_AUTH`
* `U_API@%`
  * Password: `U_API`
  * Role: `R_API`
* `U_ADMIN@%`
  * Password: `U_ADMIN`
  * Role: `R_ADMIN`
* `U_SUPER_USER`
  * Password: `U_SUPER_USER`
  * **All Privileges**

## How to...

### Start using Docker
```sh
$ docker compose up --build --force-recreate -d
```

### Regenerate fake data
First go to `data-generator/` run:
```sh
$ npm install && npm run gen
```

Get the output file at `data-generator/data.sql`

### DB Reset / Force recreate MySQL data (Only with docker-compose)

**WARNING**: *Require PowerShell*

```powershell
> ./clean-up.ps1
```

### Folder structure

* `backup/`: Folder mounted on Docker container for extracting backup file / SQL dump.
* `data/`: MySQL data folder mounted on Docker container.
* `data-generator/`: NPM JS project that help to generate fake `data.sql`.
* `.env`: Environment vars used by Docker Compose to configure container.
* `clean-up.ps1`: PowerShell script that clean MySQL data and fast restart Docker container.
* `data.sql`: Fake data (INSERTs).
* `schema.sql`: Database structure script (Databases, Tables, Users...).